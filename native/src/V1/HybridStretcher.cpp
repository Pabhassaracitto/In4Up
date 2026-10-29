// HybridStretcher.cpp
#include "UltraTimeStretch.h"

namespace UltraTimeStretch {

HybridStretcher::HybridStretcher(int sampleRate)
    : sampleRate_(sampleRate)
    , currentSpeed_(1.0f)
    , targetSpeed_(1.0f)
    , needsReinit_(false)
{
    options_.quality = Quality::Standard;
    initializeForSpeed(1.0f);
}

HybridStretcher::~HybridStretcher() = default;

void HybridStretcher::initializeForSpeed(float speed) {
    // Determine optimal FFT size based on speed
    int fftSize;
    int hopDivisor;
    
    if (speed < 0.15f) {
        // Very slow - need large FFT for quality
        fftSize = 8192;
        hopDivisor = 8;
    } else if (speed < 0.3f) {
        fftSize = 4096;
        hopDivisor = 6;
    } else if (speed < 0.5f) {
        fftSize = 2048;
        hopDivisor = 4;
    } else if (speed <= 2.0f) {
        fftSize = 1024;
        hopDivisor = 4;
    } else {
        // Fast playback
        fftSize = 512;
        hopDivisor = 2;
    }
    
    // Override with user options if specified
    if (options_.fftSize > 0) {
        fftSize = options_.fftSize;
    }
    
    int hopSize = fftSize / hopDivisor;
    
    // Create processors
    phaseVocoder_ = std::make_unique<PhaseVocoder>(fftSize, hopSize, sampleRate_);
    wsola_ = std::make_unique<WSOLAProcessor>(fftSize, sampleRate_);
    transientDetector_ = std::make_unique<TransientDetector>(sampleRate_);
    
    phaseVocoder_->setTimeStretchRatio(speed);
    phaseVocoder_->setOptions(options_);
    wsola_->setTimeStretchRatio(speed);
    transientDetector_->setSensitivity(options_.transientSensitivity);
    
    // Allocate blend buffers
    int maxBufferSize = fftSize * 4;
    pvBuffer_.resize(maxBufferSize);
    wsolaBuffer_.resize(maxBufferSize);
    blendMask_.resize(maxBufferSize);
    
    currentSpeed_ = speed;
    needsReinit_ = false;
}

void HybridStretcher::setSpeed(float speed) {
    speed = std::clamp(speed, MIN_SPEED, MAX_SPEED);
    targetSpeed_ = speed;
    
    // Check if we need to reinitialize
    if (std::abs(speed - currentSpeed_) > 0.5f ||
        (speed < 0.3f && currentSpeed_ >= 0.3f) ||
        (speed >= 0.3f && currentSpeed_ < 0.3f)) {
        needsReinit_ = true;
    } else {
        // Just update ratios
        phaseVocoder_->setTimeStretchRatio(speed);
        wsola_->setTimeStretchRatio(speed);
        currentSpeed_ = speed;
    }
}

void HybridStretcher::setOptions(const Options& options) {
    options_ = options;
    if (phaseVocoder_) {
        phaseVocoder_->setOptions(options);
    }
    if (transientDetector_) {
        transientDetector_->setSensitivity(options.transientSensitivity);
    }
}

void HybridStretcher::blendOutputs(const float* pvOutput, const float* wsolaOutput,
                                    const float* transientMask, float* output, int samples) {
    // Intelligent blending based on transient detection and speed
    float baseWsolaWeight = 0.0f;
    
    // At extreme slow speeds, favor Phase Vocoder for tonal content
    if (currentSpeed_ < 0.3f) {
        baseWsolaWeight = 0.1f;  // Mostly PV
    } else if (currentSpeed_ < 0.7f) {
        baseWsolaWeight = 0.3f;
    } else if (currentSpeed_ <= 1.5f) {
        baseWsolaWeight = 0.5f;  // Balanced
    } else {
        baseWsolaWeight = 0.7f;  // Favor WSOLA for fast playback
    }
    
    for (int i = 0; i < samples; ++i) {
        float transient = transientMask ? transientMask[i] : 0.0f;
        
        // More WSOLA weight for transients to preserve attacks
        float wsolaWeight = baseWsolaWeight + transient * (1.0f - baseWsolaWeight);
        float pvWeight = 1.0f - wsolaWeight;
        
        output[i] = pvOutput[i] * pvWeight + wsolaOutput[i] * wsolaWeight;
    }
}

void HybridStretcher::process(const float* input, int inputSamples,
                               float* output, int& outputSamples) {
    if (needsReinit_) {
        initializeForSpeed(targetSpeed_);
    }
    
    if (inputSamples <= 0) {
        outputSamples = 0;
        return;
    }
    
    // Detect transients
    if (options_.preserveTransients) {
        transientDetector_->process(input, inputSamples);
    }
    
    // Process with Phase Vocoder
    int pvOutputSamples = 0;
    phaseVocoder_->processBlock(input, inputSamples, pvBuffer_.data(), pvOutputSamples);
    
    // Process with WSOLA
    int wsolaOutputSamples = 0;
    wsola_->processBlock(input, inputSamples, wsolaBuffer_.data(), wsolaOutputSamples);
    
    // Use minimum of both outputs
    outputSamples = std::min(pvOutputSamples, wsolaOutputSamples);
    
    // Build transient mask for output samples
    if (options_.preserveTransients && outputSamples > 0) {
        float stretchFactor = currentSpeed_;
        for (int i = 0; i < outputSamples; ++i) {
            int inputIdx = static_cast<int>(i / stretchFactor);
            inputIdx = std::clamp(inputIdx, 0, inputSamples - 1);
            blendMask_[i] = transientDetector_->getTransientStrength(inputIdx);
        }
        
        blendOutputs(pvBuffer_.data(), wsolaBuffer_.data(), blendMask_.data(), 
                     output, outputSamples);
    } else {
        // Simple blend without transient info
        blendOutputs(pvBuffer_.data(), wsolaBuffer_.data(), nullptr, 
                     output, outputSamples);
    }
    
    // Apply smoothing if enabled
    if (options_.smoothTransitions && outputSamples > 2) {
        // Simple 3-point smoothing filter
        float prev = output[0];
        for (int i = 1; i < outputSamples - 1; ++i) {
            float curr = output[i];
            output[i] = 0.25f * prev + 0.5f * curr + 0.25f * output[i+1];
            prev = curr;
        }
    }
}

void HybridStretcher::processInterleaved(const float* input, int inputFrames, int channels,
                                          float* output, int& outputFrames) {
    // De-interleave, process each channel, re-interleave
    std::vector<float> monoInput(inputFrames);
    std::vector<float> monoOutput(inputFrames * 10);  // Max stretch ratio buffer
    
    int minOutputFrames = INT_MAX;
    
    for (int ch = 0; ch < channels; ++ch) {
        // Extract channel
        for (int i = 0; i < inputFrames; ++i) {
            monoInput[i] = input[i * channels + ch];
        }
        
        // Process
        int outSamples = 0;
        process(monoInput.data(), inputFrames, monoOutput.data(), outSamples);
        
        minOutputFrames = std::min(minOutputFrames, outSamples);
        
        // Write to output (interleaved)
        for (int i = 0; i < outSamples; ++i) {
            output[i * channels + ch] = monoOutput[i];
        }
    }
    
    outputFrames = minOutputFrames;
}

void HybridStretcher::reset() {
    if (phaseVocoder_) phaseVocoder_->reset();
    if (wsola_) wsola_->reset();
    if (transientDetector_) transientDetector_->reset();
}

int HybridStretcher::getLatency() const {
    if (phaseVocoder_) {
        return phaseVocoder_->getLatency();
    }
    return 0;
}

} // namespace UltraTimeStretch