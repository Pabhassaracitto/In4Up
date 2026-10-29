#include "UltraTimeStretch_V2_Enhancements.h"

#include <algorithm>
#include <cmath>

namespace UltraTimeStretch
{
    namespace V2
    {

        static inline float clamp01(float v)
        {
            return (std::max)(0.0f, (std::min)(1.0f, v));
        }

        FormantPreserver::FormantPreserver(int fftSize, int sampleRate)
            : fftSize_(fftSize),
              sampleRate_(sampleRate),
              quefrencyLimit_(0),
              smoothingWindowSize_(7),
              preservationStrength_(0.7f)
        {
            const int numBins = fftSize_ / 2 + 1;

            envelope_.assign(numBins, 1.0f);
            smoothedEnvelope_.assign(numBins, 1.0f);
            logMagnitude_.assign(numBins, 0.0f);

            workComplex_.resize(fftSize_);
            fft_ = std::make_unique<FFTProcessor>(fftSize_);

            // ~1ms quefrency
            quefrencyLimit_ = (std::max)(10, (std::min)(fftSize_ / 4, sampleRate_ / 1000));

            if ((smoothingWindowSize_ % 2) == 0)
                smoothingWindowSize_ += 1;
        }

        void FormantPreserver::setQuefrencyLimit(int samples)
        {
            quefrencyLimit_ = std::clamp(samples, 10, fftSize_ / 4);
        }

        void FormantPreserver::setSmoothingWindowSize(int sizeOdd)
        {
            smoothingWindowSize_ = std::clamp(sizeOdd, 3, 15);
            if ((smoothingWindowSize_ % 2) == 0)
                smoothingWindowSize_ += 1;
        }

        void FormantPreserver::setPreservationStrength(float strength)
        {
            preservationStrength_ = clamp01(strength);
        }

        void FormantPreserver::reset()
        {
            std::fill(envelope_.begin(), envelope_.end(), 1.0f);
            std::fill(smoothedEnvelope_.begin(), smoothedEnvelope_.end(), 1.0f);
        }

        float FormantPreserver::estimateVoicedRatio(const std::vector<float> &magnitudes) const
        {
            const int numBins = fftSize_ / 2 + 1;
            if ((int)magnitudes.size() < numBins || sampleRate_ <= 0)
                return 0.0f;

            float harmonicEnergy = 0.0f;
            float totalEnergy = 0.0f;

            // fundamental range 100-400Hz (voice heuristic)
            const int f0BinMin = (int)(100.0f * fftSize_ / (float)sampleRate_);
            const int f0BinMax = (int)(400.0f * fftSize_ / (float)sampleRate_);
            if (f0BinMin <= 0)
                return 0.0f;

            for (int k = 0; k < numBins; ++k)
            {
                float mag = magnitudes[k];
                totalEnergy += mag * mag;

                // check if near harmonic of the *lowest* candidate f0 (fast heuristic)
                for (int h = 1; h <= 10; ++h)
                {
                    int harmonicBin = f0BinMin * h;
                    if (harmonicBin >= numBins)
                        break;
                    if (std::abs(k - harmonicBin) < 3)
                    {
                        harmonicEnergy += mag * mag;
                        break;
                    }
                }
            }

            if (totalEnergy < 1e-9f)
                return 0.0f;
            return harmonicEnergy / totalEnergy; // 0..1
        }

        void FormantPreserver::applySmoothing(const std::vector<float> &input, std::vector<float> &output) const
        {
            const int numBins = fftSize_ / 2 + 1;
            if ((int)output.size() != numBins)
                output.resize(numBins);

            const int halfW = smoothingWindowSize_ / 2;
            const float denom = (halfW > 0) ? float(halfW * halfW) : 1.0f;

            for (int k = 0; k < numBins; ++k)
            {
                float sum = 0.0f;
                float wsum = 0.0f;

                for (int i = -halfW; i <= halfW; ++i)
                {
                    int idx = k + i;
                    if (idx >= 0 && idx < numBins)
                    {
                        float w = std::exp(-0.5f * float(i * i) / denom);
                        sum += input[idx] * w;
                        wsum += w;
                    }
                }

                output[k] = (wsum > 1e-12f) ? (sum / wsum) : input[k];
            }
        }

        void FormantPreserver::cepstralEnvelope(const std::vector<float> &magnitudes,
                                                std::vector<float> &envelopeOut)
        {
            const int numBins = fftSize_ / 2 + 1;
            envelopeOut.assign(numBins, 1.0f);

            const float eps = 1e-12f;

            // log magnitude -> complex spectrum
            for (int k = 0; k < numBins; ++k)
            {
                float mag = (k < (int)magnitudes.size()) ? magnitudes[k] : 0.0f;
                logMagnitude_[k] = std::log((std::max)(mag, eps));
                workComplex_[k] = std::complex<float>(logMagnitude_[k], 0.0f);
            }

            // mirror negative freqs
            for (int k = 1; k < numBins - 1; ++k)
            {
                workComplex_[fftSize_ - k] = workComplex_[k];
            }

            // IFFT -> cepstrum
            fft_->inverseInPlace(workComplex_.data());

            // liftering: keep low quefrency
            for (int n = quefrencyLimit_; n < fftSize_ - quefrencyLimit_; ++n)
            {
                workComplex_[n] = std::complex<float>(0.0f, 0.0f);
            }

            // FFT back -> smoothed log spectrum
            fft_->forwardInPlace(workComplex_.data());

            // exp -> envelope
            for (int k = 0; k < numBins; ++k)
            {
                envelopeOut[k] = std::exp(workComplex_[k].real());
            }
        }

        void FormantPreserver::extractEnvelope(const std::vector<float> &magnitudes,
                                               std::vector<float> &envelopeOut)
        {
            cepstralEnvelope(magnitudes, envelopeOut);
            // extra smoothing for stability
            applySmoothing(envelopeOut, smoothedEnvelope_);
        }

        void FormantPreserver::applyEnvelope(std::vector<float> &magnitudes,
                                             const std::vector<float> &targetEnvelope)
        {
            const int numBins = fftSize_ / 2 + 1;
            if ((int)magnitudes.size() < numBins)
                magnitudes.resize(numBins, 0.0f);
            if ((int)targetEnvelope.size() < numBins)
                return;

            // compute current envelope
            cepstralEnvelope(magnitudes, envelope_);

            const float eps = 1e-12f;
            const float alpha = preservationStrength_;

            for (int k = 0; k < numBins; ++k)
            {
                float cur = (std::max)(envelope_[k], eps);
                float tgt = (std::max)(targetEnvelope[k], eps);

                float ratio = tgt / cur;
                float gain = std::pow(ratio, alpha);
                gain = std::clamp(gain, 0.5f, 2.0f);

                magnitudes[k] *= gain;
            }
        }

        void FormantPreserver::preserveFormants(std::vector<float> &magnitudes,
                                                const std::vector<float> &originalMagnitudes)
        {
            std::vector<float> originalEnv;
            extractEnvelope(originalMagnitudes, originalEnv);
            applyEnvelope(magnitudes, originalEnv);
        }

        void FormantPreserver::preserveFormants(std::vector<std::complex<float>> &spectrum,
                                                const std::vector<float> &originalMagnitudes)
        {
            const int numBins = fftSize_ / 2 + 1;
            if ((int)spectrum.size() < numBins)
                return;

            std::vector<float> originalEnv;
            extractEnvelope(originalMagnitudes, originalEnv);

            std::vector<float> mags(numBins);
            for (int k = 0; k < numBins; ++k)
                mags[k] = std::abs(spectrum[k]);

            applyEnvelope(mags, originalEnv);

            for (int k = 0; k < numBins; ++k)
            {
                float ph = std::arg(spectrum[k]);
                spectrum[k] = std::polar(mags[k], ph);
            }
        }

    } // namespace V2
} // namespace UltraTimeStretch