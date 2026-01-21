// TransientDetector.cpp
#include "UltraTimeStretch.h"

namespace UltraTimeStretch {

TransientDetector::TransientDetector(int sampleRate)
    : sampleRate_(sampleRate)
    , sensitivity_(0.5f)
    , threshold_(0.3f)
    , adaptiveThreshold_(0.3f)
{
    int fftSize = 1024;
    fft_ = std::make_unique<FFTProcessor>(fftSize);
    spectrum_.resize(fftSize);
    previousSpectrum_.resize(fftSize / 2 + 1, 0.0f);
}

void TransientDetector::setSensitivity(float sensitivity) {
    sensitivity_ = std::clamp(sensitivity, 0.0f, 1.0f);
    // Lower threshold = more sensitive
    threshold_ = 0.5f - sensitivity_ * 0.4f;
}

float TransientDetector::computeSpectralFlux(const float* frame, int size) {
    // Compute FFT
    fft_->forward(frame, spectrum_.data());
    
    // Calculate spectral flux (half-wave rectified difference)
    float flux = 0.0f;
    int numBins = size / 2 + 1;
    
    for (int i = 0; i < numBins; ++i) {
        float magnitude = std::abs(spectrum_[i]);
        float diff = magnitude - previousSpectrum_[i];
        
        // Half-wave rectification - only consider increases
        if (diff > 0) {
            flux += diff * diff;
        }
        
        previousSpectrum_[i] = magnitude;
    }
    
    return std::sqrt(flux);
}

float TransientDetector::computeOnsetStrength(const float* frame, int size) {
    // High-frequency content method
    float hfc = 0.0f;
    fft_->forward(frame, spectrum_.data());
    
    int numBins = size / 2 + 1;
    for (int i = 0; i < numBins; ++i) {
        float magnitude = std::abs(spectrum_[i]);
        // Weight by bin index (emphasize high frequencies)
        hfc += magnitude * i;
    }
    
    return hfc / (numBins * numBins);
}

void TransientDetector::process(const float* input, int numSamples) {
    transientStrength_.resize(numSamples, 0.0f);
    transientPositions_.clear();
    onsetFunction_.clear();
    
    int frameSize = fft_->getSize();
    int hopSize = frameSize / 4;
    
    std::vector<float> frame(frameSize);
    
    // Sliding window analysis
    for (int pos = 0; pos + frameSize <= numSamples; pos += hopSize) {
        // Copy frame
        for (int i = 0; i < frameSize; ++i) {
            frame[i] = input[pos + i];
        }
        
        // Compute onset strength
        float spectralFlux = computeSpectralFlux(frame.data(), frameSize);
        float onsetStrength = computeOnsetStrength(frame.data(), frameSize);
        
        float combinedStrength = 0.7f * spectralFlux + 0.3f * onsetStrength;
        onsetFunction_.push_back(combinedStrength);
        
        // Update adaptive threshold (running median-based)
        adaptiveThreshold_ = 0.95f * adaptiveThreshold_ + 0.05f * combinedStrength;
        
        // Peak picking with threshold
        float dynamicThreshold = threshold_ * (1.0f + adaptiveThreshold_);
        
        if (combinedStrength > dynamicThreshold) {
            // Mark transient region
            transientPositions_.push_back(pos + frameSize / 2);
            
            // Spread transient strength around the position
            int spreadSamples = frameSize / 2;
            for (int i = -spreadSamples; i < spreadSamples && pos + i >= 0 && pos + i < numSamples; ++i) {
                float dist = std::abs(i) / (float)spreadSamples;
                float strength = (1.0f - dist) * combinedStrength;
                transientStrength_[pos + frameSize/2 + i] = 
                    std::max(transientStrength_[pos + frameSize/2 + i], strength);
            }
        }
    }
}

bool TransientDetector::isTransient(int sampleIndex) const {
    if (sampleIndex < 0 || sampleIndex >= (int)transientStrength_.size()) {
        return false;
    }
    return transientStrength_[sampleIndex] > threshold_;
}

float TransientDetector::getTransientStrength(int sampleIndex) const {
    if (sampleIndex < 0 || sampleIndex >= (int)transientStrength_.size()) {
        return 0.0f;
    }
    return transientStrength_[sampleIndex];
}

void TransientDetector::reset() {
    std::fill(previousSpectrum_.begin(), previousSpectrum_.end(), 0.0f);
    transientStrength_.clear();
    transientPositions_.clear();
    onsetFunction_.clear();
    adaptiveThreshold_ = threshold_;
}

} // namespace UltraTimeStretch