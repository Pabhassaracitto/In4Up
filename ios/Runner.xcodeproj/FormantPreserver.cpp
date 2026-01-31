// FormantPreserver.cpp - Formant Preservation using Cepstral Analysis
// Prevents "chipmunk effect" and preserves timbre

#include "UltraTimeStretch.h"
#include "UltraTimeStretch_V2_Enhancements.h"

namespace UltraTimeStretch {
namespace V2 {

FormantPreserver::FormantPreserver(int fftSize, int sampleRate)
    : fftSize_(fftSize)
    , sampleRate_(sampleRate)
    , quefrencyLimit_(0)
{
    int numBins = fftSize / 2 + 1;
    envelope_.resize(numBins);
    smoothedEnvelope_.resize(numBins);
    originalEnvelope_.resize(numBins);
    
    // Cepstral analysis buffers
    cepstrum_.resize(fftSize);
    logMagnitude_.resize(numBins);
    
    // Quefrency limit for envelope extraction (typically 1-2ms)
    // This separates envelope (formants) from fine structure (pitch)
    quefrencyLimit_ = sampleRate_ / 1000;  // 1ms in samples
    
    // Smoothing window for envelope extraction
    smoothingWindowSize_ = 7;  // Must be odd
    
    std::cout << "[FormantPreserver] Initialized with FFT=" << fftSize 
              << ", Quefrency limit=" << quefrencyLimit_ << std::endl;
}

FormantPreserver::~FormantPreserver() = default;

void FormantPreserver::setQuefrencyLimit(int samples) {
    quefrencyLimit_ = std::clamp(samples, 10, fftSize_ / 4);
}

void FormantPreserver::extractEnvelope(const std::vector<float>& magnitudes) {
    int numBins = fftSize_ / 2 + 1;
    
    // ═══════════════════════════════════════════════════════════════
    // METHOD 1: Simple Moving Average (Fast)
    // ═══════════════════════════════════════════════════════════════
    if (false) {  // Set to true for faster, simpler method
        int windowSize = smoothingWindowSize_;
        int halfWindow = windowSize / 2;
        
        for (int k = 0; k < numBins; ++k) {
            float sum = 0.0f;
            int count = 0;
            
            for (int i = -halfWindow; i <= halfWindow; ++i) {
                int idx = k + i;
                if (idx >= 0 && idx < numBins) {
                    sum += magnitudes[idx];
                    count++;
                }
            }
            
            envelope_[k] = (count > 0) ? (sum / count) : magnitudes[k];
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // METHOD 2: Cepstral Liftering (More Accurate)
    // ═══════════════════════════════════════════════════════════════
    else {
        // Step 1: Log magnitude spectrum
        for (int k = 0; k < numBins; ++k) {
            logMagnitude_[k] = std::log(std::max(magnitudes[k], 1e-10f));
        }
        
        // Step 2: Forward FFT to get cepstrum
        // (In practice, use DCT for efficiency)
        std::vector<std::complex<float>> complexLog(fftSize_);
        for (int k = 0; k < numBins; ++k) {
            complexLog[k] = std::complex<float>(logMagnitude_[k], 0.0f);
        }
        
        // Mirror for negative frequencies
        for (int k = numBins; k < fftSize_; ++k) {
            complexLog[k] = complexLog[fftSize_ - k];
        }
        
        // FFT -> Cepstrum
        FFTProcessor cepstralFFT(fftSize_);
        cepstralFFT.forwardInPlace(complexLog.data());
        
        for (int i = 0; i < fftSize_; ++i) {
            cepstrum_[i] = complexLog[i].real();
        }
        
        // Step 3: Liftering - Keep only low quefrencies (envelope)
        std::vector<float> lifteredCepstrum(fftSize_, 0.0f);
        
        // Keep DC and low quefrencies
        for (int i = 0; i < quefrencyLimit_ && i < fftSize_; ++i) {
            lifteredCepstrum[i] = cepstrum_[i];
        }
        
        // Step 4: Inverse FFT to get smoothed log magnitude
        std::vector<std::complex<float>> lifteredComplex(fftSize_);
        for (int i = 0; i < fftSize_; ++i) {
            lifteredComplex[i] = std::complex<float>(lifteredCepstrum[i], 0.0f);
        }
        
        cepstralFFT.inverseInPlace(lifteredComplex.data());
        
        // Step 5: Exp to get envelope in linear scale
        for (int k = 0; k < numBins; ++k) {
            envelope_[k] = std::exp(lifteredComplex[k].real());
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Additional smoothing for stability
    // ═══════════════════════════════════════════════════════════════
    applySmoothing(envelope_, smoothedEnvelope_);
    
    // Store original for later restoration
    originalEnvelope_ = smoothedEnvelope_;
}

void FormantPreserver::applySmoothing(const std::vector<float>& input, 
                                       std::vector<float>& output) {
    int numBins = fftSize_ / 2 + 1;
    int windowSize = smoothingWindowSize_;
    int halfWindow = windowSize / 2;
    
    for (int k = 0; k < numBins; ++k) {
        float sum = 0.0f;
        float weightSum = 0.0f;
        
        // Gaussian-like weighting
        for (int i = -halfWindow; i <= halfWindow; ++i) {
            int idx = k + i;
            if (idx >= 0 && idx < numBins) {
                float weight = std::exp(-0.5f * (i * i) / (halfWindow * halfWindow));
                sum += input[idx] * weight;
                weightSum += weight;
            }
        }
        
        output[k] = (weightSum > 1e-6f) ? (sum / weightSum) : input[k];
    }
}

void FormantPreserver::applyEnvelope(std::vector<float>& magnitudes) {
    int numBins = fftSize_ / 2 + 1;
    
    // ═══════════════════════════════════════════════════════════════
    // Apply formant envelope to stretched magnitudes
    // ═══════════════════════════════════════════════════════════════
    
    for (int k = 0; k < numBins; ++k) {
        if (magnitudes[k] > 1e-10f && smoothedEnvelope_[k] > 1e-10f) {
            // Calculate envelope transfer ratio
            float currentEnvelope = magnitudes[k];
            float targetEnvelope = smoothedEnvelope_[k];
            float ratio = targetEnvelope / currentEnvelope;
            
            // Apply with partial strength to avoid over-correction
            float strength = 0.7f;  // 70% formant preservation
            float adjustedRatio = std::pow(ratio, strength);
            
            // Limit ratio to avoid extreme values
            adjustedRatio = std::clamp(adjustedRatio, 0.5f, 2.0f);
            
            magnitudes[k] *= adjustedRatio;
        }
    }
}

void FormantPreserver::preserveFormants(std::vector<std::complex<float>>& spectrum,
                                         const std::vector<float>& originalMagnitudes) {
    int numBins = fftSize_ / 2 + 1;
    
    // Extract envelope from original
    extractEnvelope(originalMagnitudes);
    
    // Get current magnitudes
    std::vector<float> currentMagnitudes(numBins);
    for (int k = 0; k < numBins; ++k) {
        currentMagnitudes[k] = std::abs(spectrum[k]);
    }
    
    // Apply envelope correction
    applyEnvelope(currentMagnitudes);
    
    // Reconstruct spectrum with corrected magnitudes but original phases
    for (int k = 0; k < numBins; ++k) {
        float phase = std::arg(spectrum[k]);
        spectrum[k] = std::polar(currentMagnitudes[k], phase);
    }
}

void FormantPreserver::reset() {
    std::fill(envelope_.begin(), envelope_.end(), 0.0f);
    std::fill(smoothedEnvelope_.begin(), smoothedEnvelope_.end(), 0.0f);
    std::fill(originalEnvelope_.begin(), originalEnvelope_.end(), 0.0f);
}

void FormantPreserver::setPreservationStrength(float strength) {
    preservationStrength_ = std::clamp(strength, 0.0f, 1.0f);
}

const std::vector<float>& FormantPreserver::getEnvelope() const {
    return smoothedEnvelope_;
}

void FormantPreserver::setSmoothingWindowSize(int size) {
    smoothingWindowSize_ = std::clamp(size, 3, 15);
    // Ensure odd number
    if (smoothingWindowSize_ % 2 == 0) {
        smoothingWindowSize_++;
    }
}

// ═══════════════════════════════════════════════════════════════
// Advanced: Adaptive formant preservation based on signal type
// ═══════════════════════════════════════════════════════════════
float FormantPreserver::estimateVoicedRatio(const std::vector<float>& magnitudes) {
    int numBins = fftSize_ / 2 + 1;
    
    // Calculate harmonicity - ratio of energy at harmonic frequencies
    float harmonicEnergy = 0.0f;
    float totalEnergy = 0.0f;
    
    // Assume fundamental around 100-400 Hz for human voice
    int f0BinMin = (int)(100.0f * fftSize_ / sampleRate_);
    int f0BinMax = (int)(400.0f * fftSize_ / sampleRate_);
    
    for (int k = 0; k < numBins; ++k) {
        float mag = magnitudes[k];
        totalEnergy += mag * mag;
        
        // Check if this bin is near a harmonic of potential F0
        for (int h = 1; h <= 10; ++h) {
            int harmonicBin = f0BinMin * h;
            if (std::abs(k - harmonicBin) < 3) {
                harmonicEnergy += mag * mag;
                break;
            }
        }
    }
    
    return (totalEnergy > 1e-6f) ? (harmonicEnergy / totalEnergy) : 0.0f;
}

} // namespace V2
} // namespace UltraTimeStretch
