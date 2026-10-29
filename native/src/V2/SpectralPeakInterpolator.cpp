// SpectralPeakInterpolator.cpp - Sub-bin Frequency Estimation
// Advanced + build-safe + low overhead (no std::cout in realtime)

#include "UltraTimeStretch_V2_Enhancements.h"

#include <algorithm>
#include <cmath>

namespace UltraTimeStretch
{
    namespace V2
    {

        SpectralPeakInterpolator::SpectralPeakInterpolator(int fftSize, int sampleRate)
            : fftSize_(fftSize),
              sampleRate_(sampleRate),
              numBins_(fftSize / 2 + 1),
              peakThreshold_(0.01f)
        {
            peakMagnitudes_.assign(numBins_, 0.0f);
            peakPhases_.assign(numBins_, 0.0f);
            peakFrequencies_.assign(numBins_, 0.0f);
            isPeak_.assign(numBins_, 0);
        }

        void SpectralPeakInterpolator::setPeakThreshold(float threshold)
        {
            peakThreshold_ = std::clamp(threshold, 0.001f, 0.5f);
        }

        const std::vector<int> &SpectralPeakInterpolator::getPeakIndices() const
        {
            return detectedPeaks_;
        }

        float SpectralPeakInterpolator::getPeakFrequency(int binIndex) const
        {
            if (binIndex < 0 || binIndex >= numBins_)
                return 0.0f;
            return peakFrequencies_[binIndex];
        }

        float SpectralPeakInterpolator::getPeakMagnitude(int binIndex) const
        {
            if (binIndex < 0 || binIndex >= numBins_)
                return 0.0f;
            return peakMagnitudes_[binIndex];
        }

        bool SpectralPeakInterpolator::isPeak(int binIndex) const
        {
            if (binIndex < 0 || binIndex >= numBins_)
                return false;
            return isPeak_[binIndex] != 0;
        }

        void SpectralPeakInterpolator::reset()
        {
            detectedPeaks_.clear();
            std::fill(isPeak_.begin(), isPeak_.end(), 0);
            std::fill(peakMagnitudes_.begin(), peakMagnitudes_.end(), 0.0f);
            std::fill(peakPhases_.begin(), peakPhases_.end(), 0.0f);
            std::fill(peakFrequencies_.begin(), peakFrequencies_.end(), 0.0f);
        }

        void SpectralPeakInterpolator::detectPeaks(const std::vector<float> &magnitudes)
        {
            if ((int)magnitudes.size() != numBins_)
            {
                detectedPeaks_.clear();
                std::fill(isPeak_.begin(), isPeak_.end(), 0);
                return;
            }

            // relative threshold
            float maxMag = 0.0f;
            for (float v : magnitudes)
                maxMag = (std::max)(maxMag, v);
            float thr = maxMag * peakThreshold_;

            detectedPeaks_.clear();
            std::fill(isPeak_.begin(), isPeak_.end(), 0);

            for (int k = 1; k < numBins_ - 1; ++k)
            {
                float c = magnitudes[k];
                if (c > thr && c > magnitudes[k - 1] && c > magnitudes[k + 1])
                {
                    isPeak_[k] = 1;
                    detectedPeaks_.push_back(k);
                }
            }
        }

        float SpectralPeakInterpolator::parabolicInterpolation(float alpha, float beta, float gamma,
                                                               float &interpolatedMag) const
        {
            float denom = alpha - 2.0f * beta + gamma;
            if (std::abs(denom) < 1e-10f)
            {
                interpolatedMag = beta;
                return 0.0f;
            }

            float offset = 0.5f * (alpha - gamma) / denom;
            offset = std::clamp(offset, -0.5f, 0.5f);

            interpolatedMag = beta - 0.25f * (alpha - gamma) * offset;
            return offset;
        }

        float SpectralPeakInterpolator::quadraticInterpolation(float y1, float y2, float y3,
                                                               float &interpolatedValue) const
        {
            float a = 0.5f * (y1 + y3) - y2;
            float b = 0.5f * (y3 - y1);

            if (std::abs(a) < 1e-10f)
            {
                interpolatedValue = y2;
                return 0.0f;
            }

            float peakPos = -b / (2.0f * a);
            peakPos = std::clamp(peakPos, -0.5f, 0.5f);

            interpolatedValue = a * peakPos * peakPos + b * peakPos + y2;
            return peakPos;
        }

        float SpectralPeakInterpolator::estimateFrequencyFromPhase(
            const std::vector<float> &currentPhases,
            const std::vector<float> &previousPhases,
            int binIndex, int hopSize) const
        {
            if (binIndex < 0 || binIndex >= (int)currentPhases.size() ||
                binIndex >= (int)previousPhases.size())
            {
                return 0.0f;
            }

            float phaseDiff = currentPhases[binIndex] - previousPhases[binIndex];

            // unwrap
            while (phaseDiff > PI)
                phaseDiff -= TWO_PI;
            while (phaseDiff < -PI)
                phaseDiff += TWO_PI;

            float expectedPhase = TWO_PI * binIndex * hopSize / (float)fftSize_;
            float phaseDeviation = phaseDiff - expectedPhase;

            float binFrequency = (float)binIndex * (float)sampleRate_ / (float)fftSize_;
            float frequencyDeviation = phaseDeviation * (float)sampleRate_ / (TWO_PI * (float)hopSize);

            return binFrequency + frequencyDeviation;
        }

        void SpectralPeakInterpolator::interpolatePeaks(const std::vector<float> &magnitudes,
                                                        const std::vector<float> &phases,
                                                        std::vector<float> &interpMag,
                                                        std::vector<float> &interpPhase)
        {
            if ((int)magnitudes.size() != numBins_ || (int)phases.size() != numBins_)
            {
                return;
            }

            interpMag = magnitudes;
            interpPhase = phases;

            detectPeaks(magnitudes);

            for (int k : detectedPeaks_)
            {
                if (k < 1 || k >= numBins_ - 1)
                    continue;

                float alpha = magnitudes[k - 1];
                float beta = magnitudes[k];
                float gamma = magnitudes[k + 1];

                float interpolatedMag = 0.0f;
                float offset = parabolicInterpolation(alpha, beta, gamma, interpolatedMag);

                peakMagnitudes_[k] = interpolatedMag;
                peakFrequencies_[k] = (float)k + offset;

                // linear phase interpolation
                peakPhases_[k] = phases[k] + offset * (phases[k + 1] - phases[k]);

                interpMag[k] = interpolatedMag;
                interpPhase[k] = peakPhases_[k];
            }
        }

        void SpectralPeakInterpolator::interpolateSpectrum(std::vector<std::complex<float>> &spectrum,
                                                           const std::vector<float> &magnitudes,
                                                           const std::vector<float> &phases)
        {
            std::vector<float> interpMag, interpPhase;
            interpolatePeaks(magnitudes, phases, interpMag, interpPhase);

            if ((int)spectrum.size() < numBins_)
                spectrum.resize(numBins_);

            for (int k = 0; k < numBins_; ++k)
            {
                spectrum[k] = std::polar(interpMag[k], interpPhase[k]);
            }
        }

    } // namespace V2
} // namespace UltraTimeStretch