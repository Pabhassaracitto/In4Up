// PhaseVocoder_Enhanced.cpp - Enhanced version with extreme slow stretch support
#include "UltraTimeStretch.h"
#include <cstring>

namespace UltraTimeStretch {

PhaseVocoder::PhaseVocoder(int fftSize, int hopSize, int sampleRate)
    : fftSize_(fftSize)
    , analysisHop_(hopSize)
    , synthesisHop_(hopSize)
    , sampleRate_(sampleRate)
    , timeStretchRatio_(1.0f)
    , pitchShiftRatio_(1.0f)
    , analysisPhase_(0.0f)
    , synthesisPhase_(0.0f)
    , accumulatorReadPos_(0)
    , accumulatorWritePos_(0)
{
    fft_ = std::make_unique<FFTProcessor>(fftSize_);
    
    // Allocate buffers
    analysisWindow_.resize(fftSize_);
    synthesisWindow_.resize(fftSize_);
    inputBuffer_.resize(fftSize_ * 2);
    outputBuffer_.resize(fftSize_ * 2);
    spectrum_.resize(fftSize_);
    magnitudes_.resize(fftSize_ / 2 + 1);
    phases_.resize(fftSize_ / 2 + 1);
    previousPhases_.resize(fftSize_ / 2 + 1, 0.0f);
    synthesisPhases_.resize(fftSize_ / 2 + 1, 0.0f);
    frequencies_.resize(fftSize_ / 2 + 1);
    outputAccumulator_.resize(fftSize_ * 4, 0.0f);
    
    // Build windows
    buildWindows();
}

PhaseVocoder::~PhaseVocoder() = default;

void PhaseVocoder::buildWindows() {
    // Hann window for analysis
    for (int i = 0; i < fftSize_; ++i) {
        analysisWindow_[i] = 0.5f * (1.0f - std::cos(TWO_PI * i / fftSize_));
    }
    
    // Synthesis window - normalized for perfect reconstruction
    for (int i = 0; i < fftSize_; ++i) {
        synthesisWindow_[i] = analysisWindow_[i];
    }
    
    // Normalize synthesis window
    float windowSum = 0.0f;
    int overlapCount = fftSize_ / synthesisHop_;
    for (int i = 0; i < fftSize_; i += synthesisHop_) {
        if (i < fftSize_) {
            windowSum += synthesisWindow_[i] * synthesisWindow_[i];
        }
    }
    
    if (windowSum > 0.0f) {
        float normFactor = 1.0f / std::sqrt(windowSum * overlapCount);
        for (int i = 0; i < fftSize_; ++i) {
            synthesisWindow_[i] *= normFactor;
        }
    }
}

void PhaseVocoder::setTimeStretchRatio(float ratio) {
    timeStretchRatio_ = std::clamp(ratio, MIN_SPEED, MAX_SPEED);
    synthesisHop_ = static_cast<int>(analysisHop_ * ratio);
    synthesisHop_ = std::max(1, synthesisHop_);
}

void PhaseVocoder::setPitchShiftRatio(float ratio) {
    pitchShiftRatio_ = std::clamp(ratio, 0.25f, 4.0f);
}

void PhaseVocoder::setOptions(const Options& options) {
    options_ = options;
}

void PhaseVocoder::analyzeFrame(const float* input) {
    // Apply window and FFT
    std::vector<float> windowed(fftSize_);
    for (int i = 0; i < fftSize_; ++i) {
        windowed[i] = input[i] * analysisWindow_[i];
    }
    
    fft_->forward(windowed.data(), spectrum_.data());
    
    // Extract magnitude and phase
    int numBins = fftSize_ / 2 + 1;
    for (int k = 0; k < numBins; ++k) {
        magnitudes_[k] = std::abs(spectrum_[k]);
        phases_[k] = std::arg(spectrum_[k]);
    }
}

void PhaseVocoder::processPhases() {
    int numBins = fftSize_ / 2 + 1;
    float expectedPhaseAdvance = TWO_PI * analysisHop_ / fftSize_;
    
    for (int k = 0; k < numBins; ++k) {
        // Calculate instantaneous frequency
        float phaseDiff = phases_[k] - previousPhases_[k];
        
        // Unwrap phase difference
        while (phaseDiff > PI) phaseDiff -= TWO_PI;
        while (phaseDiff < -PI) phaseDiff += TWO_PI;
        
        // True frequency = bin frequency + deviation
        float binFreq = TWO_PI * k / fftSize_;
        float deviation = (phaseDiff - expectedPhaseAdvance * k) / analysisHop_;
        frequencies_[k] = binFreq + deviation;
        
        // Update synthesis phase
        synthesisPhases_[k] += frequencies_[k] * synthesisHop_;
        
        // Keep phase in [-π, π]
        while (synthesisPhases_[k] > PI) synthesisPhases_[k] -= TWO_PI;
        while (synthesisPhases_[k] < -PI) synthesisPhases_[k] += TWO_PI;
        
        previousPhases_[k] = phases_[k];
    }
}

void PhaseVocoder::applyPhaseLocking() {
    if (!options_.preserveFormants) {
        return;
    }
    
    int numBins = fftSize_ / 2 + 1;
    float threshold = 0.1f * (*std::max_element(magnitudes_.begin(), magnitudes_.end()));
    
    peakIndices_.clear();
    
    // Find spectral peaks
    for (int k = 2; k < numBins - 2; ++k) {
        if (magnitudes_[k] > threshold &&
            magnitudes_[k] > magnitudes_[k-1] &&
            magnitudes_[k] > magnitudes_[k+1] &&
            magnitudes_[k] > magnitudes_[k-2] &&
            magnitudes_[k] > magnitudes_[k+2]) {
            peakIndices_.push_back(k);
        }
    }
    
    // Lock phases in regions around peaks
    for (int peakIdx : peakIndices_) {
        float peakPhase = synthesisPhases_[peakIdx];
        
        // Lock neighboring bins
        int regionSize = 3;
        for (int offset = -regionSize; offset <= regionSize; ++offset) {
            int k = peakIdx + offset;
            if (k >= 0 && k < numBins && offset != 0) {
                float weight = 1.0f - std::abs(offset) / (float)(regionSize + 1);
                synthesisPhases_[k] = synthesisPhases_[k] * (1.0f - weight) + 
                                     (peakPhase + offset * frequencies_[peakIdx]) * weight;
            }
        }
    }
}

void PhaseVocoder::synthesizeFrame(float* output) {
    int numBins = fftSize_ / 2 + 1;
    
    // Reconstruct complex spectrum
    for (int k = 0; k < numBins; ++k) {
        float mag = magnitudes_[k];
        float phase = synthesisPhases_[k];
        spectrum_[k] = std::polar(mag, phase);
    }
    
    // Mirror for negative frequencies
    for (int k = numBins; k < fftSize_; ++k) {
        spectrum_[k] = std::conj(spectrum_[fftSize_ - k]);
    }
    
    // IFFT
    fft_->inverseInPlace(spectrum_.data());
    
    // Apply synthesis window and accumulate
    for (int i = 0; i < fftSize_; ++i) {
        int writeIdx = (accumulatorWritePos_ + i) % outputAccumulator_.size();
        outputAccumulator_[writeIdx] += spectrum_[i].real() * synthesisWindow_[i];
    }
    
    // Copy output
    for (int i = 0; i < synthesisHop_; ++i) {
        int readIdx = (accumulatorReadPos_ + i) % outputAccumulator_.size();
        output[i] = outputAccumulator_[readIdx];
        outputAccumulator_[readIdx] = 0.0f;  // Clear after reading
    }
    
    accumulatorReadPos_ = (accumulatorReadPos_ + synthesisHop_) % outputAccumulator_.size();
    accumulatorWritePos_ = (accumulatorWritePos_ + synthesisHop_) % outputAccumulator_.size();
}

void PhaseVocoder::processFrame(const float* input, float* output) {
    analyzeFrame(input);
    processPhases();
    applyPhaseLocking();
    synthesizeFrame(output);
}

void PhaseVocoder::processBlock(const float* input, int inputSamples,
                                 float* output, int& outputSamples) {
    outputSamples = 0;
    
    int inputPos = 0;
    std::vector<float> frameOutput(synthesisHop_);
    
    while (inputPos + fftSize_ <= inputSamples) {
        processFrame(input + inputPos, frameOutput.data());
        
        // Copy to output
        for (int i = 0; i < synthesisHop_ && outputSamples < inputSamples * 10; ++i) {
            output[outputSamples++] = frameOutput[i];
        }
        
        inputPos += analysisHop_;
    }
}

void PhaseVocoder::reset() {
    std::fill(previousPhases_.begin(), previousPhases_.end(), 0.0f);
    std::fill(synthesisPhases_.begin(), synthesisPhases_.end(), 0.0f);
    std::fill(outputAccumulator_.begin(), outputAccumulator_.end(), 0.0f);
    accumulatorReadPos_ = 0;
    accumulatorWritePos_ = 0;
}

int PhaseVocoder::getLatency() const {
    return fftSize_ / 2;
}

} // namespace UltraTimeStretch