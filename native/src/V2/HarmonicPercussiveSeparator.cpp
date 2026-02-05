// HarmonicPercussiveSeparator.cpp - Harmonic-Percussive Separation
// Based on Fitzgerald (2010) median filtering approach

#include "UltraTimeStretch_V2_Enhancements.h"

#include <algorithm>
#include <cmath>
#include <complex>
#include <vector>
#include <iostream>

#if defined(UTS_DEBUG) || defined(UTS_DEBUG_LOG)
#include <iostream>
#define HPS_LOG(x)                   \
    do                               \
    {                                \
        std::cerr << x << std::endl; \
    } while (0)
#else
#define HPS_LOG(x) \
    do             \
    {              \
    } while (0)
#endif

namespace UltraTimeStretch
{
    namespace V2
    {

        HarmonicPercussiveSeparator::HarmonicPercussiveSeparator(int fftSize, int sampleRate)
            : fftSize_(fftSize), sampleRate_(sampleRate), spectrogramPos_(0)
        {
            fft_ = std::make_unique<FFTProcessor>(fftSize_);

            int numBins = fftSize_ / 2 + 1;
            harmonicMask_.resize(numBins);
            percussiveMask_.resize(numBins);

            // Spectrogram buffer: store multiple time frames for median filtering
            spectrogramFrames_ = 16;
            spectrogram_.resize(spectrogramFrames_);
            for (auto &frame : spectrogram_)
            {
                frame.resize(numBins);
                std::fill(frame.begin(), frame.end(), 0.0f);
            }

            // Temporary buffers
            harmonicSpectrum_.resize(fftSize_);
            percussiveSpectrum_.resize(fftSize_);

            // Median filter kernel sizes
            harmonicMedianLength_ = 17;  // time
            percussiveMedianLength_ = 5; // freq
        }

        HarmonicPercussiveSeparator::~HarmonicPercussiveSeparator() = default;

        void HarmonicPercussiveSeparator::setMedianLengths(int harmonicLength, int percussiveLength)
        {
            harmonicMedianLength_ = std::clamp(harmonicLength, 3, 31);
            percussiveMedianLength_ = std::clamp(percussiveLength, 3, 11);

            // khuyến nghị: percussive median length nên là số lẻ
            if ((percussiveMedianLength_ % 2) == 0)
                percussiveMedianLength_ += 1;
        }

        float HarmonicPercussiveSeparator::computeMedian(std::vector<float> &values)
        {
            if (values.empty())
                return 0.0f;

            size_t mid = values.size() / 2;
            std::nth_element(values.begin(), values.begin() + mid, values.end());

            if (values.size() % 2 == 0)
            {
                float mid1 = values[mid];
                auto maxIt = std::max_element(values.begin(), values.begin() + mid);
                return (*maxIt + mid1) / 2.0f;
            }
            else
            {
                return values[mid];
            }
        }

        void HarmonicPercussiveSeparator::updateSpectrogram(const std::complex<float> *spectrum)
        {
            int numBins = fftSize_ / 2 + 1;

            spectrogramPos_ = (spectrogramPos_ + 1) % spectrogramFrames_;

            for (int k = 0; k < numBins; ++k)
            {
                spectrogram_[spectrogramPos_][k] = std::abs(spectrum[k]);
            }
        }

        void HarmonicPercussiveSeparator::computeMasks()
        {
            int numBins = fftSize_ / 2 + 1;

            // HARMONIC mask: median across time
            for (int k = 0; k < numBins; ++k)
            {
                std::vector<float> timeSlice;
                timeSlice.reserve((size_t)harmonicMedianLength_);

                for (int t = 0; t < harmonicMedianLength_ && t < spectrogramFrames_; ++t)
                {
                    int idx = (spectrogramPos_ - harmonicMedianLength_ / 2 + t + spectrogramFrames_) % spectrogramFrames_;
                    timeSlice.push_back(spectrogram_[idx][k]);
                }

                harmonicMask_[k] = computeMedian(timeSlice);
            }

            // PERCUSSIVE mask: median across frequency neighborhood
            for (int k = 0; k < numBins; ++k)
            {
                std::vector<float> freqSlice;
                freqSlice.reserve((size_t)percussiveMedianLength_);

                int startBin = (std::max)(0, k - percussiveMedianLength_ / 2);
                int endBin = (std::min)(numBins - 1, k + percussiveMedianLength_ / 2);

                for (int f = startBin; f <= endBin; ++f)
                {
                    freqSlice.push_back(spectrogram_[spectrogramPos_][f]);
                }

                percussiveMask_[k] = computeMedian(freqSlice);
            }

            // SOFT masks normalize + power (Wiener-like)
            for (int k = 0; k < numBins; ++k)
            {
                float currentMag = spectrogram_[spectrogramPos_][k];

                if (currentMag > 1e-6f)
                {
                    float h = harmonicMask_[k];
                    float p = percussiveMask_[k];
                    float total = h + p;

                    if (total > 1e-6f)
                    {
                        h /= total;
                        p /= total;
                    }
                    else
                    {
                        h = 0.5f;
                        p = 0.5f;
                    }

                    const float beta = 2.0f;
                    h = std::pow(h, beta);
                    p = std::pow(p, beta);

                    total = h + p;
                    if (total > 1e-6f)
                    {
                        h /= total;
                        p /= total;
                    }

                    harmonicMask_[k] = h;
                    percussiveMask_[k] = p;
                }
                else
                {
                    harmonicMask_[k] = 0.5f;
                    percussiveMask_[k] = 0.5f;
                }
            }
        }

        void HarmonicPercussiveSeparator::separate(const float *input, int numSamples,
                                                   float *harmonic, float *percussive)
        {
            if (!input || !harmonic || !percussive || numSamples <= 0)
                return;

            if (numSamples != fftSize_)
            {
                HPS_LOG("[HPS] Warning: Input size " << numSamples << " != FFT size " << fftSize_);
                std::fill(harmonic, harmonic + numSamples, 0.0f);
                std::fill(percussive, percussive + numSamples, 0.0f);
                return;
            }

            int numBins = fftSize_ / 2 + 1;

            // STEP 1: Forward FFT
            std::vector<std::complex<float>> spectrum(fftSize_);
            fft_->forward(input, spectrum.data());

            // STEP 2: Update spectrogram and compute masks
            updateSpectrogram(spectrum.data());
            computeMasks();

            // STEP 3: Apply masks
            for (int k = 0; k < numBins; ++k)
            {
                harmonicSpectrum_[k] = spectrum[k] * harmonicMask_[k];
                percussiveSpectrum_[k] = spectrum[k] * percussiveMask_[k];
            }

            // Mirror for negative frequencies (conjugate symmetry)
            for (int k = numBins; k < fftSize_; ++k)
            {
                int mirrorIdx = fftSize_ - k;
                harmonicSpectrum_[k] = std::conj(harmonicSpectrum_[mirrorIdx]);
                percussiveSpectrum_[k] = std::conj(percussiveSpectrum_[mirrorIdx]);
            }

            // STEP 4: Inverse FFT
            fft_->inverse(harmonicSpectrum_.data(), harmonic);
            fft_->inverse(percussiveSpectrum_.data(), percussive);
        }

        void HarmonicPercussiveSeparator::separateWithOverlap(const float *input, int numSamples,
                                                              float *harmonic, float *percussive)
        {
            if (!input || !harmonic || !percussive || numSamples <= 0)
                return;

            int hopSize = fftSize_ / 4; // 75% overlap
            std::vector<float> window(fftSize_);

            // Hann window
            for (int i = 0; i < fftSize_; ++i)
            {
                window[i] = 0.5f * (1.0f - std::cos(TWO_PI * i / (float)fftSize_));
            }

            std::vector<float> harmonicAccum(numSamples + fftSize_, 0.0f);
            std::vector<float> percussiveAccum(numSamples + fftSize_, 0.0f);
            std::vector<float> windowAccum(numSamples + fftSize_, 0.0f);

            std::vector<float> frame(fftSize_);
            std::vector<float> harmonicFrame(fftSize_);
            std::vector<float> percussiveFrame(fftSize_);

            for (int pos = 0; pos + fftSize_ <= numSamples; pos += hopSize)
            {
                for (int i = 0; i < fftSize_; ++i)
                {
                    frame[i] = input[pos + i] * window[i];
                }

                separate(frame.data(), fftSize_, harmonicFrame.data(), percussiveFrame.data());

                for (int i = 0; i < fftSize_; ++i)
                {
                    harmonicAccum[pos + i] += harmonicFrame[i] * window[i];
                    percussiveAccum[pos + i] += percussiveFrame[i] * window[i];
                    windowAccum[pos + i] += window[i] * window[i];
                }
            }

            for (int i = 0; i < numSamples; ++i)
            {
                if (windowAccum[i] > 1e-6f)
                {
                    harmonic[i] = harmonicAccum[i] / windowAccum[i];
                    percussive[i] = percussiveAccum[i] / windowAccum[i];
                }
                else
                {
                    harmonic[i] = 0.0f;
                    percussive[i] = 0.0f;
                }
            }
        }

        void HarmonicPercussiveSeparator::reset()
        {
            for (auto &frame : spectrogram_)
            {
                std::fill(frame.begin(), frame.end(), 0.0f);
            }
            spectrogramPos_ = 0;
        }

        float HarmonicPercussiveSeparator::getHarmonicRatio(int binIndex) const
        {
            if (binIndex < 0 || binIndex >= (int)harmonicMask_.size())
                return 0.0f;
            return harmonicMask_[binIndex];
        }

        float HarmonicPercussiveSeparator::getPercussiveRatio(int binIndex) const
        {
            if (binIndex < 0 || binIndex >= (int)percussiveMask_.size())
                return 0.0f;
            return percussiveMask_[binIndex];
        }

    } // namespace V2
} // namespace UltraTimeStretch