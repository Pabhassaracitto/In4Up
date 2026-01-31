// UltraTimeStretch_V2_Enhancements.h
// Các cải tiến chính cho extreme slow stretch (0.05x - 0.1x)

#ifndef ULTRA_TIME_STRETCH_V2_H
#define ULTRA_TIME_STRETCH_V2_H

#include "UltraTimeStretch.h"
#include <map>

namespace UltraTimeStretch {
namespace V2 {

//==============================================================================
// NEW: Adaptive FFT Size Manager
// Tự động chọn FFT size tối ưu dựa trên tốc độ và tần số nội dung
//==============================================================================
class AdaptiveFFTManager {
public:
    struct FFTConfig {
        int size;
        int hopDivisor;
        int overlapFactor;
        float qualityScore;
    };
    
    static FFTConfig getOptimalConfig(float speed, Quality quality) {
        FFTConfig config;
        
        // Extreme slow speeds need HUGE FFT for clarity
        if (speed < 0.1f) {
            if (quality == Quality::UltraQuality) {
                config.size = 16384;      // 2x larger than before!
                config.hopDivisor = 16;   // More overlap
                config.overlapFactor = 8;
                config.qualityScore = 10.0f;
            } else {
                config.size = 8192;
                config.hopDivisor = 8;
                config.overlapFactor = 6;
                config.qualityScore = 8.0f;
            }
        } else if (speed < 0.2f) {
            config.size = 8192;
            config.hopDivisor = 8;
            config.overlapFactor = 6;
            config.qualityScore = 8.0f;
        } else if (speed < 0.3f) {
            config.size = 4096;
            config.hopDivisor = 6;
            config.overlapFactor = 4;
            config.qualityScore = 7.0f;
        } else if (speed < 0.5f) {
            config.size = 2048;
            config.hopDivisor = 4;
            config.overlapFactor = 4;
            config.qualityScore = 6.0f;
        } else if (speed <= 1.5f) {
            config.size = 1024;
            config.hopDivisor = 4;
            config.overlapFactor = 4;
            config.qualityScore = 5.0f;
        } else {
            config.size = 512;
            config.hopDivisor = 2;
            config.overlapFactor = 2;
            config.qualityScore = 4.0f;
        }
        
        return config;
    }
};

//==============================================================================
// NEW: Multi-Resolution Phase Vocoder
// Sử dụng nhiều độ phân giải FFT song song để giữ cả chi tiết và tông
//==============================================================================
class MultiResolutionPV {
public:
    struct Resolution {
        std::unique_ptr<PhaseVocoder> processor;
        int fftSize;
        float weight;
    };
    
    MultiResolutionPV(int sampleRate, float speed) : sampleRate_(sampleRate) {
        initializeResolutions(speed);
    }
    
    void initializeResolutions(float speed) {
        resolutions_.clear();
        
        if (speed < 0.15f) {
            // Ultra slow: 3 resolutions
            // Large FFT for tonal clarity
            Resolution large;
            large.fftSize = 16384;
            large.processor = std::make_unique<PhaseVocoder>(16384, 16384/16, sampleRate_);
            large.weight = 0.6f;
            resolutions_.push_back(std::move(large));
            
            // Medium FFT for balance
            Resolution medium;
            medium.fftSize = 4096;
            medium.processor = std::make_unique<PhaseVocoder>(4096, 4096/8, sampleRate_);
            medium.weight = 0.3f;
            resolutions_.push_back(std::move(medium));
            
            // Small FFT for transients
            Resolution small;
            small.fftSize = 1024;
            small.processor = std::make_unique<PhaseVocoder>(1024, 1024/4, sampleRate_);
            small.weight = 0.1f;
            resolutions_.push_back(std::move(small));
        } else {
            // Normal speed: single resolution
            Resolution single;
            single.fftSize = 2048;
            single.processor = std::make_unique<PhaseVocoder>(2048, 2048/4, sampleRate_);
            single.weight = 1.0f;
            resolutions_.push_back(std::move(single));
        }
    }
    
    void setSpeed(float speed) {
        for (auto& res : resolutions_) {
            res.processor->setTimeStretchRatio(speed);
        }
    }
    
    void process(const float* input, int inputSamples, float* output, int& outputSamples) {
        if (resolutions_.size() == 1) {
            // Single resolution path
            resolutions_[0].processor->processBlock(input, inputSamples, output, outputSamples);
            return;
        }
        
        // Multi-resolution processing
        std::vector<std::vector<float>> outputs(resolutions_.size());
        std::vector<int> outSampleCounts(resolutions_.size());
        
        for (size_t i = 0; i < resolutions_.size(); ++i) {
            outputs[i].resize(inputSamples * 10);
            resolutions_[i].processor->processBlock(
                input, inputSamples, 
                outputs[i].data(), outSampleCounts[i]
            );
        }
        
        // Blend outputs with weights
        outputSamples = *std::min_element(outSampleCounts.begin(), outSampleCounts.end());
        
        for (int i = 0; i < outputSamples; ++i) {
            float blended = 0.0f;
            for (size_t r = 0; r < resolutions_.size(); ++r) {
                blended += outputs[r][i] * resolutions_[r].weight;
            }
            output[i] = blended;
        }
    }
    
    void reset() {
        for (auto& res : resolutions_) {
            res.processor->reset();
        }
    }
    
private:
    int sampleRate_;
    std::vector<Resolution> resolutions_;
};

//==============================================================================
// NEW: Harmonic Percussive Separator
// Tách tín hiệu thành harmonic và percussive để xử lý riêng
//==============================================================================
class HarmonicPercussiveSeparator {
public:
    HarmonicPercussiveSeparator(int fftSize, int sampleRate) 
        : fftSize_(fftSize), sampleRate_(sampleRate) {
        
        fft_ = std::make_unique<FFTProcessor>(fftSize);
        
        int numBins = fftSize / 2 + 1;
        harmonicMask_.resize(numBins);
        percussiveMask_.resize(numBins);
        spectrogram_.resize(16);  // Time frames for median filtering
        for (auto& frame : spectrogram_) {
            frame.resize(numBins);
        }
    }
    
    void separate(const float* input, int numSamples,
                  float* harmonic, float* percussive) {
        
        std::vector<std::complex<float>> spectrum(fftSize_);
        fft_->forward(input, spectrum.data());
        
        int numBins = fftSize_ / 2 + 1;
        
        // Update spectrogram
        spectrogramPos_ = (spectrogramPos_ + 1) % spectrogram_.size();
        for (int k = 0; k < numBins; ++k) {
            spectrogram_[spectrogramPos_][k] = std::abs(spectrum[k]);
        }
        
        // Compute median filters
        for (int k = 0; k < numBins; ++k) {
            // Horizontal median (harmonic)
            std::vector<float> timeSlice;
            for (const auto& frame : spectrogram_) {
                timeSlice.push_back(frame[k]);
            }
            std::sort(timeSlice.begin(), timeSlice.end());
            float harmonicMedian = timeSlice[timeSlice.size() / 2];
            
            // Vertical median (percussive)
            std::vector<float> freqSlice;
            int start = std::max(0, k - 2);
            int end = std::min(numBins - 1, k + 2);
            for (int j = start; j <= end; ++j) {
                freqSlice.push_back(spectrogram_[spectrogramPos_][j]);
            }
            std::sort(freqSlice.begin(), freqSlice.end());
            float percussiveMedian = freqSlice[freqSlice.size() / 2];
            
            // Soft masks
            float currentMag = std::abs(spectrum[k]);
            if (currentMag > 1e-6f) {
                harmonicMask_[k] = harmonicMedian / currentMag;
                percussiveMask_[k] = percussiveMedian / currentMag;
                
                // Normalize
                float sum = harmonicMask_[k] + percussiveMask_[k];
                if (sum > 1e-6f) {
                    harmonicMask_[k] /= sum;
                    percussiveMask_[k] /= sum;
                }
            } else {
                harmonicMask_[k] = 0.5f;
                percussiveMask_[k] = 0.5f;
            }
        }
        
        // Apply masks and reconstruct
        std::vector<std::complex<float>> harmonicSpec(fftSize_);
        std::vector<std::complex<float>> percussiveSpec(fftSize_);
        
        for (int k = 0; k < numBins; ++k) {
            harmonicSpec[k] = spectrum[k] * harmonicMask_[k];
            percussiveSpec[k] = spectrum[k] * percussiveMask_[k];
        }
        
        // Mirror for negative frequencies
        for (int k = numBins; k < fftSize_; ++k) {
            harmonicSpec[k] = std::conj(harmonicSpec[fftSize_ - k]);
            percussiveSpec[k] = std::conj(percussiveSpec[fftSize_ - k]);
        }
        
        fft_->inverse(harmonicSpec.data(), harmonic);
        fft_->inverse(percussiveSpec.data(), percussive);
    }
    
    void reset() {
        for (auto& frame : spectrogram_) {
            std::fill(frame.begin(), frame.end(), 0.0f);
        }
        spectrogramPos_ = 0;
    }
    
private:
    int fftSize_;
    int sampleRate_;
    std::unique_ptr<FFTProcessor> fft_;
    std::vector<float> harmonicMask_;
    std::vector<float> percussiveMask_;
    std::vector<std::vector<float>> spectrogram_;
    int spectrogramPos_ = 0;
};

//==============================================================================
// NEW: Enhanced Engine V2
//==============================================================================
class EngineV2 : public Engine {
public:
    EngineV2() : Engine() {
        useMultiResolution_ = false;
        useHPSeparation_ = false;
    }
    
    bool initialize(int sampleRate, int channels, const Options& options) {
        bool result = Engine::initialize(sampleRate, channels, options);
        
        if (result && options.quality == Quality::UltraQuality) {
            useMultiResolution_ = true;
            multiResPV_ = std::make_unique<MultiResolutionPV>(sampleRate, 1.0f);
            
            useHPSeparation_ = true;
            hpSeparator_ = std::make_unique<HarmonicPercussiveSeparator>(2048, sampleRate);
        }
        
        return result;
    }
    
    void setSpeed(float speed) {
        Engine::setSpeed(speed);
        
        if (multiResPV_) {
            multiResPV_->setSpeed(speed);
        }
        
        // Enable multi-resolution for extreme slow speeds
        if (speed < 0.15f && !useMultiResolution_) {
            useMultiResolution_ = true;
            multiResPV_ = std::make_unique<MultiResolutionPV>(getSampleRate(), speed);
        }
    }
    
    int processV2(const float* input, int inputSamples, 
                  float* output, int maxOutputSamples) {
        if (!useMultiResolution_) {
            return Engine::process(input, inputSamples, output, maxOutputSamples);
        }
        
        int outputSamples = 0;
        multiResPV_->process(input, inputSamples, output, outputSamples);
        return std::min(outputSamples, maxOutputSamples);
    }
    
private:
    bool useMultiResolution_;
    bool useHPSeparation_;
    std::unique_ptr<MultiResolutionPV> multiResPV_;
    std::unique_ptr<HarmonicPercussiveSeparator> hpSeparator_;
};

} // namespace V2
} // namespace UltraTimeStretch

#endif // ULTRA_TIME_STRETCH_V2_H