// HarmonicPercussiveSeparator.cpp - Harmonic-Percussive Separation
// Based on Fitzgerald (2010) median filtering approach

#include "UltraTimeStretch.h"
#include "UltraTimeStretch_V2_Enhancements.h"

namespace UltraTimeStretch {
namespace V2 {

HarmonicPercussiveSeparator::HarmonicPercussiveSeparator(int fftSize, int sampleRate)
    : fftSize_(fftSize)
    , sampleRate_(sampleRate)
    , spectrogramPos_(0)
{
    fft_ = std::make_unique<FFTProcessor>(fftSize);
    
    int numBins = fftSize / 2 + 1;
    harmonicMask_.resize(numBins);
    percussiveMask_.resize(numBins);
    
    // Spectrogram buffer: store multiple time frames for median filtering
    spectrogramFrames_ = 16;  // Number of frames to keep
    spectrogram_.resize(spectrogramFrames_);
    for (auto& frame : spectrogram_) {
        frame.resize(numBins);
        std::fill(frame.begin(), frame.end(), 0.0f);
    }
    
    // Temporary buffers
    harmonicSpectrum_.resize(fftSize);
    percussiveSpectrum_.resize(fftSize);
    
    // Median filter kernel sizes
    harmonicMedianLength_ = 17;  // Horizontal (time) - longer for harmonic
    percussiveMedianLength_ = 5;  // Vertical (frequency) - shorter for percussive
}

HarmonicPercussiveSeparator::~HarmonicPercussiveSeparator() = default;

void HarmonicPercussiveSeparator::setMedianLengths(int harmonicLength, int percussiveLength) {
    harmonicMedianLength_ = std::clamp(harmonicLength, 3, 31);
    percussiveMedianLength_ = std::clamp(percussiveLength, 3, 11);
}

float HarmonicPercussiveSeparator::computeMedian(std::vector<float>& values) {
    if (values.empty()) return 0.0f;
    
    // Partial sort to find median
    size_t mid = values.size() / 2;
    std::nth_element(values.begin(), values.begin() + mid, values.end());
    
    if (values.size() % 2 == 0) {
        // Even number of elements - average of two middle values
        float mid1 = values[mid];
        auto maxIt = std::max_element(values.begin(), values.begin() + mid);
        return (*maxIt + mid1) / 2.0f;
    } else {
        return values[mid];
    }
}

void HarmonicPercussiveSeparator::updateSpectrogram(const std::complex<float>* spectrum) {
    int numBins = fftSize_ / 2 + 1;
    
    // Update circular buffer position
    spectrogramPos_ = (spectrogramPos_ + 1) % spectrogramFrames_;
    
    // Store magnitudes in current frame
    for (int k = 0; k < numBins; ++k) {
        spectrogram_[spectrogramPos_][k] = std::abs(spectrum[k]);
    }
}

void HarmonicPercussiveSeparator::computeMasks() {
    int numBins = fftSize_ / 2 + 1;
    
    // ═══════════════════════════════════════════════════════════════
    // HARMONIC MASK: Horizontal median filtering
    // Harmonic content is stable across time
    // ═══════════════════════════════════════════════════════════════
    for (int k = 0; k < numBins; ++k) {
        std::vector<float> timeSlice;
        timeSlice.reserve(harmonicMedianLength_);
        
        // Collect time slice around current position
        for (int t = 0; t < harmonicMedianLength_ && t < spectrogramFrames_; ++t) {
            int idx = (spectrogramPos_ - harmonicMedianLength_/2 + t + spectrogramFrames_) % spectrogramFrames_;
            timeSlice.push_back(spectrogram_[idx][k]);
        }
        
        harmonicMask_[k] = computeMedian(timeSlice);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PERCUSSIVE MASK: Vertical median filtering
    // Percussive content is broadband across frequencies
    // ═══════════════════════════════════════════════════════════════
    for (int k = 0; k < numBins; ++k) {
        std::vector<float> freqSlice;
        freqSlice.reserve(percussiveMedianLength_);
        
        // Collect frequency slice around current bin
        int startBin = std::max(0, k - percussiveMedianLength_/2);
        int endBin = std::min(numBins - 1, k + percussiveMedianLength_/2);
        
        for (int f = startBin; f <= endBin; ++f) {
            freqSlice.push_back(spectrogram_[spectrogramPos_][f]);
        }
        
        percussiveMask_[k] = computeMedian(freqSlice);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // SOFT MASKING: Binary masks -> Ratio masks
    // ═══════════════════════════════════════════════════════════════
    for (int k = 0; k < numBins; ++k) {
        float currentMag = spectrogram_[spectrogramPos_][k];
        
        if (currentMag > 1e-6f) {
            // Normalize masks
            float harmonic = harmonicMask_[k];
            float percussive = percussiveMask_[k];
            float total = harmonic + percussive;
            
            if (total > 1e-6f) {
                harmonicMask_[k] = harmonic / total;
                percussiveMask_[k] = percussive / total;
            } else {
                // No strong component - split equally
                harmonicMask_[k] = 0.5f;
                percussiveMask_[k] = 0.5f;
            }
            
            // Apply power for softer separation
            float beta = 2.0f;  // Wiener-like filtering parameter
            harmonicMask_[k] = std::pow(harmonicMask_[k], beta);
            percussiveMask_[k] = std::pow(percussiveMask_[k], beta);
            
            // Re-normalize after power
            total = harmonicMask_[k] + percussiveMask_[k];
            if (total > 1e-6f) {
                harmonicMask_[k] /= total;
                percussiveMask_[k] /= total;
            }
        } else {
            harmonicMask_[k] = 0.5f;
            percussiveMask_[k] = 0.5f;
        }
    }
}

void HarmonicPercussiveSeparator::separate(const float* input, int numSamples,
                                            float* harmonic, float* percussive) {
    if (numSamples != fftSize_) {
        // For now, require exact FFT size input
        // In production, would handle windowing/overlap-add
        std::cerr << "[HPS] Warning: Input size " << numSamples 
                  << " != FFT size " << fftSize_ << std::endl;
        std::fill(harmonic, harmonic + numSamples, 0.0f);
        std::fill(percussive, percussive + numSamples, 0.0f);
        return;
    }
    
    int numBins = fftSize_ / 2 + 1;
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 1: Forward FFT
    // ═══════════════════════════════════════════════════════════════
    std::vector<std::complex<float>> spectrum(fftSize_);
    fft_->forward(input, spectrum.data());
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 2: Update spectrogram and compute masks
    // ═══════════════════════════════════════════════════════════════
    updateSpectrogram(spectrum.data());
    computeMasks();
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 3: Apply masks to separate components
    // ═══════════════════════════════════════════════════════════════
    
    // Positive frequencies
    for (int k = 0; k < numBins; ++k) {
        harmonicSpectrum_[k] = spectrum[k] * harmonicMask_[k];
        percussiveSpectrum_[k] = spectrum[k] * percussiveMask_[k];
    }
    
    // Mirror for negative frequencies (conjugate symmetry)
    for (int k = numBins; k < fftSize_; ++k) {
        int mirrorIdx = fftSize_ - k;
        harmonicSpectrum_[k] = std::conj(harmonicSpectrum_[mirrorIdx]);
        percussiveSpectrum_[k] = std::conj(percussiveSpectrum_[mirrorIdx]);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 4: Inverse FFT to reconstruct time-domain signals
    // ═══════════════════════════════════════════════════════════════
    fft_->inverse(harmonicSpectrum_.data(), harmonic);
    fft_->inverse(percussiveSpectrum_.data(), percussive);
}

void HarmonicPercussiveSeparator::separateWithOverlap(const float* input, int numSamples,
                                                       float* harmonic, float* percussive) {
    // ═══════════════════════════════════════════════════════════════
    // Overlap-Add STFT for arbitrary length input
    // ═══════════════════════════════════════════════════════════════
    
    int hopSize = fftSize_ / 4;  // 75% overlap
    std::vector<float> window(fftSize_);
    
    // Hann window
    for (int i = 0; i < fftSize_; ++i) {
        window[i] = 0.5f * (1.0f - std::cos(TWO_PI * i / fftSize_));
    }
    
    // Initialize output accumulators
    std::vector<float> harmonicAccum(numSamples + fftSize_, 0.0f);
    std::vector<float> percussiveAccum(numSamples + fftSize_, 0.0f);
    std::vector<float> windowAccum(numSamples + fftSize_, 0.0f);
    
    // Process overlapping frames
    std::vector<float> frame(fftSize_);
    std::vector<float> harmonicFrame(fftSize_);
    std::vector<float> percussiveFrame(fftSize_);
    
    for (int pos = 0; pos + fftSize_ <= numSamples; pos += hopSize) {
        // Extract and window frame
        for (int i = 0; i < fftSize_; ++i) {
            frame[i] = input[pos + i] * window[i];
        }
        
        // Separate
        separate(frame.data(), fftSize_, harmonicFrame.data(), percussiveFrame.data());
        
        // Accumulate with window
        for (int i = 0; i < fftSize_; ++i) {
            harmonicAccum[pos + i] += harmonicFrame[i] * window[i];
            percussiveAccum[pos + i] += percussiveFrame[i] * window[i];
            windowAccum[pos + i] += window[i] * window[i];
        }
    }
    
    // Normalize by window accumulation
    for (int i = 0; i < numSamples; ++i) {
        if (windowAccum[i] > 1e-6f) {
            harmonic[i] = harmonicAccum[i] / windowAccum[i];
            percussive[i] = percussiveAccum[i] / windowAccum[i];
        } else {
            harmonic[i] = 0.0f;
            percussive[i] = 0.0f;
        }
    }
}

void HarmonicPercussiveSeparator::reset() {
    for (auto& frame : spectrogram_) {
        std::fill(frame.begin(), frame.end(), 0.0f);
    }
    spectrogramPos_ = 0;
}

float HarmonicPercussiveSeparator::getHarmonicRatio(int binIndex) const {
    if (binIndex < 0 || binIndex >= (int)harmonicMask_.size()) {
        return 0.0f;
    }
    return harmonicMask_[binIndex];
}

float HarmonicPercussiveSeparator::getPercussiveRatio(int binIndex) const {
    if (binIndex < 0 || binIndex >= (int)percussiveMask_.size()) {
        return 0.0f;
    }
    return percussiveMask_[binIndex];
}

} // namespace V2
} // namespace UltraTimeStretch
