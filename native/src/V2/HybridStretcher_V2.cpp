// HybridStretcher_V2.cpp - Enhanced with advanced algorithms
#include "UltraTimeStretch.h"

namespace UltraTimeStretch {

// New: Spectral Peak Interpolator for better clarity at slow speeds
class SpectralPeakInterpolator {
public:
    SpectralPeakInterpolator(int fftSize) : fftSize_(fftSize) {
        peakMagnitudes_.resize(fftSize / 2 + 1);
        peakPhases_.resize(fftSize / 2 + 1);
        peakFrequencies_.resize(fftSize / 2 + 1);
    }
    
    void interpolatePeaks(const std::vector<float>& magnitudes,
                          const std::vector<float>& phases,
                          std::vector<float>& interpMag,
                          std::vector<float>& interpPhase) {
        int numBins = fftSize_ / 2 + 1;
        
        // Find peaks using parabolic interpolation
        for (int k = 1; k < numBins - 1; ++k) {
            if (magnitudes[k] > magnitudes[k-1] && magnitudes[k] > magnitudes[k+1]) {
                // Parabolic interpolation for sub-bin precision
                float alpha = magnitudes[k-1];
                float beta = magnitudes[k];
                float gamma = magnitudes[k+1];
                
                float p = 0.5f * (alpha - gamma) / (alpha - 2.0f * beta + gamma);
                float interpolatedMag = beta - 0.25f * (alpha - gamma) * p;
                
                peakMagnitudes_[k] = interpolatedMag;
                peakPhases_[k] = phases[k];
                peakFrequencies_[k] = k + p;
            } else {
                peakMagnitudes_[k] = magnitudes[k];
                peakPhases_[k] = phases[k];
                peakFrequencies_[k] = k;
            }
        }
        
        interpMag = peakMagnitudes_;
        interpPhase = peakPhases_;
    }
    
private:
    int fftSize_;
    std::vector<float> peakMagnitudes_;
    std::vector<float> peakPhases_;
    std::vector<float> peakFrequencies_;
};

// New: Formant Preserving Processor
class FormantPreserver {
public:
    FormantPreserver(int fftSize, int sampleRate) 
        : fftSize_(fftSize), sampleRate_(sampleRate) {
        envelope_.resize(fftSize / 2 + 1);
        smoothedEnvelope_.resize(fftSize / 2 + 1);
    }
    
    void extractEnvelope(const std::vector<float>& magnitudes) {
        int numBins = fftSize_ / 2 + 1;
        
        // Extract spectral envelope using cepstral method
        int quefrencyLimit = sampleRate_ / 1000;  // ~1ms
        
        for (int k = 0; k < numBins; ++k) {
            envelope_[k] = magnitudes[k];
        }
        
        // Smooth envelope (simple moving average)
        int smoothWindow = 5;
        for (int k = smoothWindow; k < numBins - smoothWindow; ++k) {
            float sum = 0.0f;
            for (int i = -smoothWindow; i <= smoothWindow; ++i) {
                sum += envelope_[k + i];
            }
            smoothedEnvelope_[k] = sum / (2 * smoothWindow + 1);
        }
    }
    
    void applyEnvelope(std::vector<float>& magnitudes) {
        int numBins = fftSize_ / 2 + 1;
        
        for (int k = 0; k < numBins; ++k) {
            if (smoothedEnvelope_[k] > 1e-6f) {
                float ratio = smoothedEnvelope_[k] / (magnitudes[k] + 1e-6f);
                magnitudes[k] *= std::pow(ratio, 0.7f);  // Partial application
            }
        }
    }
    
private:
    int fftSize_;
    int sampleRate_;
    std::vector<float> envelope_;
    std::vector<float> smoothedEnvelope_;
};

// Enhanced HybridStretcher
class HybridStretcherV2 : public HybridStretcher {
public:
    HybridStretcherV2(int sampleRate) : HybridStretcher(sampleRate) {
        peakInterpolator_ = std::make_unique<SpectralPeakInterpolator>(2048);
        formantPreserver_ = std::make_unique<FormantPreserver>(2048, sampleRate);
    }
    
    void setQualityMode(Quality mode) {
        qualityMode_ = mode;
        
        // Adjust parameters based on quality
        switch (mode) {
            case Quality::UltraQuality:
                useSpectralInterpolation_ = true;
                useFormantPreservation_ = true;
                useAdaptiveBlending_ = true;
                break;
            case Quality::HighQuality:
                useSpectralInterpolation_ = true;
                useFormantPreservation_ = false;
                useAdaptiveBlending_ = true;
                break;
            default:
                useSpectralInterpolation_ = false;
                useFormantPreservation_ = false;
                useAdaptiveBlending_ = true;
                break;
        }
    }
    
private:
    std::unique_ptr<SpectralPeakInterpolator> peakInterpolator_;
    std::unique_ptr<FormantPreserver> formantPreserver_;
    Quality qualityMode_;
    bool useSpectralInterpolation_;
    bool useFormantPreservation_;
    bool useAdaptiveBlending_;
};

} // namespace UltraTimeStretch