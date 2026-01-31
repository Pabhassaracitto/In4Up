// SpectralPeakInterpolator.cpp - Sub-bin Frequency Estimation
// Uses parabolic interpolation for improved frequency accuracy

#include "UltraTimeStretch.h"
#include "UltraTimeStretch_V2_Enhancements.h"

namespace UltraTimeStretch {
namespace V2 {

SpectralPeakInterpolator::SpectralPeakInterpolator(int fftSize)
    : fftSize_(fftSize)
    , numBins_(fftSize / 2 + 1)
{
    peakMagnitudes_.resize(numBins_);
    peakPhases_.resize(numBins_);
    peakFrequencies_.resize(numBins_);
    isPeak_.resize(numBins_, false);
    
    // Peak detection threshold
    peakThreshold_ = 0.01f;  // Relative threshold
}

SpectralPeakInterpolator::~SpectralPeakInterpolator() = default;

void SpectralPeakInterpolator::setPeakThreshold(float threshold) {
    peakThreshold_ = std::clamp(threshold, 0.001f, 0.5f);
}

void SpectralPeakInterpolator::detectPeaks(const std::vector<float>& magnitudes) {
    if ((int)magnitudes.size() != numBins_) {
        std::cerr << "[SpectralPeakInterpolator] Magnitude size mismatch" << std::endl;
        return;
    }
    
    // Find maximum magnitude for relative threshold
    float maxMag = *std::max_element(magnitudes.begin(), magnitudes.end());
    float threshold = maxMag * peakThreshold_;
    
    detectedPeaks_.clear();
    std::fill(isPeak_.begin(), isPeak_.end(), false);
    
    // ═══════════════════════════════════════════════════════════════
    // PEAK DETECTION with local maximum check
    // ═══════════════════════════════════════════════════════════════
    for (int k = 1; k < numBins_ - 1; ++k) {
        float current = magnitudes[k];
        float left = magnitudes[k - 1];
        float right = magnitudes[k + 1];
        
        // Check if this is a local maximum
        if (current > threshold &&
            current > left &&
            current > right) {
            
            isPeak_[k] = true;
            detectedPeaks_.push_back(k);
        }
    }
    
    std::cout << "[SpectralPeakInterpolator] Detected " << detectedPeaks_.size() 
              << " peaks" << std::endl;
}

float SpectralPeakInterpolator::parabolicInterpolation(float alpha, float beta, float gamma,
                                                        float& interpolatedMag) {
    // ═══════════════════════════════════════════════════════════════
    // Parabolic Interpolation Formula
    // Given three points: (k-1, alpha), (k, beta), (k+1, gamma)
    // Find the peak of the parabola passing through them
    // ═══════════════════════════════════════════════════════════════
    
    // Denominator check to avoid division by zero
    float denom = alpha - 2.0f * beta + gamma;
    
    if (std::abs(denom) < 1e-10f) {
        // Parabola is too flat - no meaningful interpolation
        interpolatedMag = beta;
        return 0.0f;  // No offset
    }
    
    // Offset from integer bin position
    float offset = 0.5f * (alpha - gamma) / denom;
    
    // Clamp offset to reasonable range
    offset = std::clamp(offset, -0.5f, 0.5f);
    
    // Interpolated magnitude at peak
    interpolatedMag = beta - 0.25f * (alpha - gamma) * offset;
    
    return offset;
}

void SpectralPeakInterpolator::interpolatePeaks(const std::vector<float>& magnitudes,
                                                  const std::vector<float>& phases,
                                                  std::vector<float>& interpMag,
                                                  std::vector<float>& interpPhase) {
    if ((int)magnitudes.size() != numBins_ || (int)phases.size() != numBins_) {
        std::cerr << "[SpectralPeakInterpolator] Size mismatch in interpolatePeaks" << std::endl;
        return;
    }
    
    // Initialize output with input values
    interpMag = magnitudes;
    interpPhase = phases;
    
    // First, detect peaks
    detectPeaks(magnitudes);
    
    // ═══════════════════════════════════════════════════════════════
    // INTERPOLATE EACH DETECTED PEAK
    // ═══════════════════════════════════════════════════════════════
    for (int k : detectedPeaks_) {
        if (k < 1 || k >= numBins_ - 1) continue;
        
        float alpha = magnitudes[k - 1];
        float beta = magnitudes[k];
        float gamma = magnitudes[k + 1];
        
        float interpolatedMag;
        float offset = parabolicInterpolation(alpha, beta, gamma, interpolatedMag);
        
        // Store interpolated values
        peakMagnitudes_[k] = interpolatedMag;
        peakFrequencies_[k] = k + offset;
        
        // Phase interpolation (linear)
        peakPhases_[k] = phases[k] + offset * (phases[k+1] - phases[k]);
        
        // Update output
        interpMag[k] = interpolatedMag;
        interpPhase[k] = peakPhases_[k];
    }
}

void SpectralPeakInterpolator::interpolateSpectrum(std::vector<std::complex<float>>& spectrum,
                                                    const std::vector<float>& magnitudes,
                                                    const std::vector<float>& phases) {
    std::vector<float> interpMag, interpPhase;
    interpolatePeaks(magnitudes, phases, interpMag, interpPhase);
    
    // Reconstruct complex spectrum
    for (int k = 0; k < numBins_; ++k) {
        spectrum[k] = std::polar(interpMag[k], interpPhase[k]);
    }
}

const std::vector<int>& SpectralPeakInterpolator::getPeakIndices() const {
    return detectedPeaks_;
}

float SpectralPeakInterpolator::getPeakFrequency(int binIndex) const {
    if (binIndex < 0 || binIndex >= numBins_) {
        return 0.0f;
    }
    return peakFrequencies_[binIndex];
}

float SpectralPeakInterpolator::getPeakMagnitude(int binIndex) const {
    if (binIndex < 0 || binIndex >= numBins_) {
        return 0.0f;
    }
    return peakMagnitudes_[binIndex];
}

bool SpectralPeakInterpolator::isPeak(int binIndex) const {
    if (binIndex < 0 || binIndex >= numBins_) {
        return false;
    }
    return isPeak_[binIndex];
}

void SpectralPeakInterpolator::reset() {
    detectedPeaks_.clear();
    std::fill(isPeak_.begin(), isPeak_.end(), false);
    std::fill(peakMagnitudes_.begin(), peakMagnitudes_.end(), 0.0f);
    std::fill(peakPhases_.begin(), peakPhases_.end(), 0.0f);
    std::fill(peakFrequencies_.begin(), peakFrequencies_.end(), 0.0f);
}

// ═══════════════════════════════════════════════════════════════
// Advanced: Quadratic interpolation (more accurate but slower)
// ═══════════════════════════════════════════════════════════════
float SpectralPeakInterpolator::quadraticInterpolation(float y1, float y2, float y3,
                                                         float& interpolatedValue) {
    // Using three points: (-1, y1), (0, y2), (1, y3)
    // Fit y = ax² + bx + c
    // Peak at x = -b/(2a)
    
    float a = 0.5f * (y1 + y3) - y2;
    float b = 0.5f * (y3 - y1);
    
    if (std::abs(a) < 1e-10f) {
        interpolatedValue = y2;
        return 0.0f;
    }
    
    float peakPos = -b / (2.0f * a);
    peakPos = std::clamp(peakPos, -0.5f, 0.5f);
    
    // Evaluate at peak
    interpolatedValue = a * peakPos * peakPos + b * peakPos + y2;
    
    return peakPos;
}

// ═══════════════════════════════════════════════════════════════
// Phase-based frequency estimation
// ═══════════════════════════════════════════════════════════════
float SpectralPeakInterpolator::estimateFrequencyFromPhase(
    const std::vector<float>& currentPhases,
    const std::vector<float>& previousPhases,
    int binIndex, int hopSize, int sampleRate) {
    
    if (binIndex < 0 || binIndex >= (int)currentPhases.size()) {
        return 0.0f;
    }
    
    float phaseDiff = currentPhases[binIndex] - previousPhases[binIndex];
    
    // Unwrap phase difference
    while (phaseDiff > PI) phaseDiff -= TWO_PI;
    while (phaseDiff < -PI) phaseDiff += TWO_PI;
    
    // Expected phase advance for this bin
    float expectedPhase = TWO_PI * binIndex * hopSize / fftSize_;
    
    // Deviation from expected
    float phaseDeviation = phaseDiff - expectedPhase;
    
    // Convert to frequency
    float binFrequency = (float)binIndex * sampleRate / fftSize_;
    float frequencyDeviation = phaseDeviation * sampleRate / (TWO_PI * hopSize);
    
    return binFrequency + frequencyDeviation;
}

} // namespace V2
} // namespace UltraTimeStretch
