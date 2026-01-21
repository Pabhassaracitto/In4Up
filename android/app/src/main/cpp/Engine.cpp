// Engine.cpp
#include "UltraTimeStretch.h"

namespace UltraTimeStretch {

Engine::Engine()
    : initialized_(false)
    , sampleRate_(44100)
    , channels_(2)
    , speed_(1.0f)
    , pitch_(0.0f)
{
}

Engine::~Engine() {
    shutdown();
}

bool Engine::initialize(int sampleRate, int channels, const Options& options) {
    if (initialized_) {
        shutdown();
    }
    
    if (sampleRate <= 0 || channels <= 0 || channels > MAX_CHANNELS) {
        return false;
    }
    
    sampleRate_ = sampleRate;
    channels_ = channels;
    options_ = options;
    speed_ = 1.0f;
    pitch_ = 0.0f;
    
    // Create processor for each channel
    channelProcessors_.resize(channels);
    for (int ch = 0; ch < channels; ++ch) {
        channelProcessors_[ch] = std::make_unique<HybridStretcher>(sampleRate);
        channelProcessors_[ch]->setOptions(options);
    }
    
    // Allocate channel buffers
    int maxBufferSize = 65536;
    inputChannels_.resize(channels);
    outputChannels_.resize(channels);
    for (int ch = 0; ch < channels; ++ch) {
        inputChannels_[ch].resize(maxBufferSize);
        outputChannels_[ch].resize(maxBufferSize);
    }
    
    inputBuffer_.resize(maxBufferSize * channels);
    outputBuffer_.resize(maxBufferSize * channels);
    
    initialized_ = true;
    return true;
}

void Engine::shutdown() {
    channelProcessors_.clear();
    inputChannels_.clear();
    outputChannels_.clear();
    inputBuffer_.clear();
    outputBuffer_.clear();
    initialized_ = false;
}

void Engine::setSpeed(float speed) {
    speed = std::clamp(speed, MIN_SPEED, MAX_SPEED);
    speed_ = speed;
    
    for (auto& processor : channelProcessors_) {
        if (processor) {
            processor->setSpeed(speed);
        }
    }
}

void Engine::setPitch(float semitones) {
    pitch_ = std::clamp(semitones, -24.0f, 24.0f);
    // Pitch shifting can be implemented by combining speed change with resampling
    // For now, this is a placeholder for future implementation
}

void Engine::setOptions(const Options& options) {
    options_ = options;
    for (auto& processor : channelProcessors_) {
        if (processor) {
            processor->setOptions(options);
        }
    }
}

int Engine::process(const float* input, int inputSamples, 
                    float* output, int maxOutputSamples) {
    if (!initialized_ || inputSamples <= 0) {
        return 0;
    }
    
    // Single channel processing
    if (channels_ == 1) {
        int outputSamples = 0;
        channelProcessors_[0]->process(input, inputSamples, output, outputSamples);
        return std::min(outputSamples, maxOutputSamples);
    }
    
    // Multi-channel: de-interleave and process
    return processInterleaved(input, inputSamples / channels_, output, maxOutputSamples / channels_);
}

int Engine::processInterleaved(const float* input, int inputFrames,
                                float* output, int maxOutputFrames) {
    if (!initialized_ || inputFrames <= 0) {
        return 0;
    }
    
    // De-interleave input
    for (int ch = 0; ch < channels_; ++ch) {
        for (int i = 0; i < inputFrames; ++i) {
            inputChannels_[ch][i] = input[i * channels_ + ch];
        }
    }
    
    // Process each channel
    int minOutputFrames = maxOutputFrames;
    
    for (int ch = 0; ch < channels_; ++ch) {
        int outSamples = 0;
        channelProcessors_[ch]->process(
            inputChannels_[ch].data(), inputFrames,
            outputChannels_[ch].data(), outSamples
        );
        minOutputFrames = std::min(minOutputFrames, outSamples);
    }
    
    // Interleave output
    for (int i = 0; i < minOutputFrames; ++i) {
        for (int ch = 0; ch < channels_; ++ch) {
            output[i * channels_ + ch] = outputChannels_[ch][i];
        }
    }
    
    return minOutputFrames;
}

void Engine::flush() {
    // Process any remaining samples in internal buffers
    // Implementation depends on specific requirements
}

void Engine::reset() {
    for (auto& processor : channelProcessors_) {
        if (processor) {
            processor->reset();
        }
    }
    inputBuffer_.clear();
    outputBuffer_.clear();
}

int Engine::getLatency() const {
    if (!initialized_ || channelProcessors_.empty()) {
        return 0;
    }
    return channelProcessors_[0]->getLatency();
}

int Engine::getRequiredOutputBufferSize(int inputSamples) const {
    // Worst case: extreme time stretch
    float maxStretch = 1.0f / speed_;
    return static_cast<int>(inputSamples * maxStretch * 1.5f) + 1024;
}

} // namespace UltraTimeStretch