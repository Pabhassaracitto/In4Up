// MultiResolutionPV.cpp - Multi-Resolution Phase Vocoder for Extreme Slow Stretching
#include "UltraTimeStretch.h"
#include "UltraTimeStretch_V2_Enhancements.h"

namespace UltraTimeStretch {
namespace V2 {

MultiResolutionPV::MultiResolutionPV(int sampleRate, float speed) 
    : sampleRate_(sampleRate)
    , currentSpeed_(speed)
{
    initializeResolutions(speed);
}

MultiResolutionPV::~MultiResolutionPV() = default;

void MultiResolutionPV::initializeResolutions(float speed) {
    resolutions_.clear();
    
    if (speed < 0.15f) {
        // ═══════════════════════════════════════════════════════════════
        // ULTRA SLOW MODE: Use 3 parallel resolutions
        // ═══════════════════════════════════════════════════════════════
        
        // Large FFT: 16384 - For tonal clarity and pitch accuracy
        Resolution large;
        large.fftSize = 16384;
        large.hopSize = 16384 / 16;  // 1024 samples hop
        large.weight = 0.6f;  // 60% weight - emphasis on tonal content
        large.processor = std::make_unique<PhaseVocoder>(
            large.fftSize, large.hopSize, sampleRate_
        );
        large.processor->setTimeStretchRatio(speed);
        
        Options largeOpts;
        largeOpts.quality = Quality::UltraQuality;
        largeOpts.preserveFormants = true;
        largeOpts.antiAliasing = true;
        large.processor->setOptions(largeOpts);
        
        resolutions_.push_back(std::move(large));
        
        // Medium FFT: 4096 - For balanced mid-range
        Resolution medium;
        medium.fftSize = 4096;
        medium.hopSize = 4096 / 8;  // 512 samples hop
        medium.weight = 0.3f;  // 30% weight - mid-frequency balance
        medium.processor = std::make_unique<PhaseVocoder>(
            medium.fftSize, medium.hopSize, sampleRate_
        );
        medium.processor->setTimeStretchRatio(speed);
        
        Options mediumOpts;
        mediumOpts.quality = Quality::HighQuality;
        mediumOpts.preserveFormants = true;
        medium.processor->setOptions(mediumOpts);
        
        resolutions_.push_back(std::move(medium));
        
        // Small FFT: 1024 - For transient preservation
        Resolution small;
        small.fftSize = 1024;
        small.hopSize = 1024 / 4;  // 256 samples hop
        small.weight = 0.1f;  // 10% weight - transient detail
        small.processor = std::make_unique<PhaseVocoder>(
            small.fftSize, small.hopSize, sampleRate_
        );
        small.processor->setTimeStretchRatio(speed);
        
        Options smallOpts;
        smallOpts.quality = Quality::Standard;
        smallOpts.preserveTransients = true;
        small.processor->setOptions(smallOpts);
        
        resolutions_.push_back(std::move(small));
        
        std::cout << "[MultiResolutionPV] Initialized 3 resolutions for speed " 
                  << speed << "x" << std::endl;
        std::cout << "  Large:  FFT=" << large.fftSize << ", Weight=" << large.weight << std::endl;
        std::cout << "  Medium: FFT=" << medium.fftSize << ", Weight=" << medium.weight << std::endl;
        std::cout << "  Small:  FFT=" << small.fftSize << ", Weight=" << small.weight << std::endl;
        
    } else if (speed < 0.3f) {
        // ═══════════════════════════════════════════════════════════════
        // SLOW MODE: Use 2 resolutions
        // ═══════════════════════════════════════════════════════════════
        
        Resolution large;
        large.fftSize = 8192;
        large.hopSize = 8192 / 8;
        large.weight = 0.7f;
        large.processor = std::make_unique<PhaseVocoder>(
            large.fftSize, large.hopSize, sampleRate_
        );
        large.processor->setTimeStretchRatio(speed);
        resolutions_.push_back(std::move(large));
        
        Resolution small;
        small.fftSize = 2048;
        small.hopSize = 2048 / 4;
        small.weight = 0.3f;
        small.processor = std::make_unique<PhaseVocoder>(
            small.fftSize, small.hopSize, sampleRate_
        );
        small.processor->setTimeStretchRatio(speed);
        resolutions_.push_back(std::move(small));
        
        std::cout << "[MultiResolutionPV] Initialized 2 resolutions for speed " 
                  << speed << "x" << std::endl;
        
    } else {
        // ═══════════════════════════════════════════════════════════════
        // NORMAL MODE: Single resolution is sufficient
        // ═══════════════════════════════════════════════════════════════
        
        Resolution single;
        single.fftSize = 2048;
        single.hopSize = 2048 / 4;
        single.weight = 1.0f;
        single.processor = std::make_unique<PhaseVocoder>(
            single.fftSize, single.hopSize, sampleRate_
        );
        single.processor->setTimeStretchRatio(speed);
        
        Options opts;
        opts.quality = Quality::Standard;
        single.processor->setOptions(opts);
        
        resolutions_.push_back(std::move(single));
        
        std::cout << "[MultiResolutionPV] Single resolution mode for speed " 
                  << speed << "x" << std::endl;
    }
    
    currentSpeed_ = speed;
}

void MultiResolutionPV::setSpeed(float speed) {
    speed = std::clamp(speed, MIN_SPEED, MAX_SPEED);
    
    // Check if we need to re-initialize resolutions
    bool needsReinit = false;
    
    if (currentSpeed_ < 0.15f && speed >= 0.15f) needsReinit = true;
    if (currentSpeed_ >= 0.15f && speed < 0.15f) needsReinit = true;
    if (currentSpeed_ < 0.3f && speed >= 0.3f) needsReinit = true;
    if (currentSpeed_ >= 0.3f && speed < 0.3f) needsReinit = true;
    
    if (needsReinit) {
        std::cout << "[MultiResolutionPV] Speed change requires re-initialization: " 
                  << currentSpeed_ << "x → " << speed << "x" << std::endl;
        initializeResolutions(speed);
    } else {
        // Just update existing processors
        for (auto& res : resolutions_) {
            res.processor->setTimeStretchRatio(speed);
        }
        currentSpeed_ = speed;
    }
}

void MultiResolutionPV::setOptions(const Options& options) {
    for (auto& res : resolutions_) {
        res.processor->setOptions(options);
    }
}

void MultiResolutionPV::process(const float* input, int inputSamples, 
                                 float* output, int& outputSamples) {
    if (resolutions_.empty()) {
        outputSamples = 0;
        return;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // SINGLE RESOLUTION PATH (Fast)
    // ═══════════════════════════════════════════════════════════════
    if (resolutions_.size() == 1) {
        resolutions_[0].processor->processBlock(input, inputSamples, output, outputSamples);
        return;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MULTI-RESOLUTION PATH (High Quality)
    // ═══════════════════════════════════════════════════════════════
    
    // Allocate buffers for each resolution
    std::vector<std::vector<float>> outputs(resolutions_.size());
    std::vector<int> outSampleCounts(resolutions_.size());
    
    // Process each resolution in parallel (can be threaded in production)
    for (size_t i = 0; i < resolutions_.size(); ++i) {
        outputs[i].resize(inputSamples * 10);  // Max stretch buffer
        resolutions_[i].processor->processBlock(
            input, inputSamples,
            outputs[i].data(), outSampleCounts[i]
        );
    }
    
    // Find minimum output length (all resolutions must match)
    outputSamples = *std::min_element(outSampleCounts.begin(), outSampleCounts.end());
    
    if (outputSamples <= 0) {
        return;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // INTELLIGENT BLENDING
    // ═══════════════════════════════════════════════════════════════
    
    // Weighted blend with adaptive mixing
    for (int i = 0; i < outputSamples; ++i) {
        float blended = 0.0f;
        float totalWeight = 0.0f;
        
        for (size_t r = 0; r < resolutions_.size(); ++r) {
            float weight = resolutions_[r].weight;
            
            // Adaptive weighting based on signal characteristics
            // (can be enhanced with spectral analysis)
            float adaptiveWeight = weight;
            
            blended += outputs[r][i] * adaptiveWeight;
            totalWeight += adaptiveWeight;
        }
        
        // Normalize
        if (totalWeight > 1e-6f) {
            output[i] = blended / totalWeight;
        } else {
            output[i] = 0.0f;
        }
    }
    
    // Optional: Apply smoothing to blend boundaries
    if (outputSamples > 4) {
        applySmoothing(output, outputSamples);
    }
}

void MultiResolutionPV::applySmoothing(float* output, int samples) {
    // Simple 3-point moving average for smoothing
    std::vector<float> temp(samples);
    std::copy(output, output + samples, temp.begin());
    
    for (int i = 1; i < samples - 1; ++i) {
        output[i] = 0.25f * temp[i-1] + 0.5f * temp[i] + 0.25f * temp[i+1];
    }
}

void MultiResolutionPV::reset() {
    for (auto& res : resolutions_) {
        res.processor->reset();
    }
}

int MultiResolutionPV::getLatency() const {
    if (resolutions_.empty()) {
        return 0;
    }
    
    // Return latency of largest FFT (worst case)
    int maxLatency = 0;
    for (const auto& res : resolutions_) {
        maxLatency = std::max(maxLatency, res.processor->getLatency());
    }
    return maxLatency;
}

std::string MultiResolutionPV::getInfo() const {
    std::stringstream ss;
    ss << "MultiResolutionPV Info:" << std::endl;
    ss << "  Current Speed: " << currentSpeed_ << "x" << std::endl;
    ss << "  Resolutions: " << resolutions_.size() << std::endl;
    
    for (size_t i = 0; i < resolutions_.size(); ++i) {
        ss << "    [" << i << "] FFT=" << resolutions_[i].fftSize
           << ", Hop=" << resolutions_[i].hopSize
           << ", Weight=" << resolutions_[i].weight << std::endl;
    }
    
    ss << "  Total Latency: " << getLatency() << " samples" << std::endl;
    
    return ss.str();
}

} // namespace V2
} // namespace UltraTimeStretch
