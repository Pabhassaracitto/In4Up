#include "UltraTimeStretch_V2_Enhancements.h"
#include <algorithm>
#include <complex>

namespace UltraTimeStretch
{
    namespace V2
    {

        HybridStretcherV2::HybridStretcherV2(int sampleRate)
            : sampleRate_(sampleRate),
              currentSpeed_(1.0f),
              options_{},
              useHPS_(false),
              useFormants_(false),
              usePeakInterp_(false)
        {
            // Initialize base V1 engine
            base_ = std::make_unique<::UltraTimeStretch::HybridStretcher>(sampleRate);

            // Initialize V2 processors (lazy init later when needed)
            initializeProcessors();
        }

        void HybridStretcherV2::initializeProcessors()
        {
            // Pre-allocate buffers (max expected size)
            const int maxFrames = 65536;
            harmonicBuffer_.resize(maxFrames);
            percussiveBuffer_.resize(maxFrames);
            pvOutputBuffer_.resize(maxFrames);
            wsolaOutputBuffer_.resize(maxFrames);
            formantEnvelope_.resize(8192); // For FFT size up to 16384
        }

        void HybridStretcherV2::setSpeed(float speed)
        {
            currentSpeed_ = std::clamp(speed, MIN_SPEED, MAX_SPEED);

            // Update base V1 engine
            if (base_)
            {
                base_->setSpeed(currentSpeed_);
            }

            // Update V2 processors if initialized
            if (phaseVocoder_)
                phaseVocoder_->setTimeStretchRatio(speed);
            if (wsola_)
                wsola_->setTimeStretchRatio(speed);
        }

        void HybridStretcherV2::setOptions(const Options &options)
        {
            options_ = options;

            // Update base
            if (base_)
            {
                base_->setOptions(options_);
            }

            // Update V2 processors
            if (phaseVocoder_)
                phaseVocoder_->setOptions(options);

            // Auto-enable V2 features based on quality
            if (options.quality == Quality::UltraQuality)
            {
                useHPS_ = true;
                useFormants_ = options.preserveFormants;
                usePeakInterp_ = true;
            }
        }

        void HybridStretcherV2::process(const float *input, int inputSamples,
                                        float *output, int &outputSamples)
        {
            // For speeds >= 0.5x or if V2 features disabled, use base V1
            if (currentSpeed_ >= 0.5f || (!useHPS_ && !useFormants_ && !usePeakInterp_))
            {
                if (base_)
                {
                    base_->process(input, inputSamples, output, outputSamples);
                }
                else
                {
                    outputSamples = 0;
                }
                return;
            }

            // V2 ENHANCED PATH for slow speeds < 0.5x

            // Initialize V2 processors if not done yet
            if (!phaseVocoder_ || !wsola_)
            {
                // Determine FFT size based on speed
                int fftSize = (currentSpeed_ < 0.15f) ? 8192 : 4096;
                int hopSize = fftSize / 8;

                phaseVocoder_ = std::make_unique<::UltraTimeStretch::PhaseVocoder>(
                    fftSize, hopSize, sampleRate_);
                phaseVocoder_->setTimeStretchRatio(currentSpeed_);
                phaseVocoder_->setOptions(options_);

                wsola_ = std::make_unique<::UltraTimeStretch::WSOLAProcessor>(
                    fftSize, sampleRate_);
                wsola_->setTimeStretchRatio(currentSpeed_);
            }

            // Step 1: Harmonic-Percussive Separation (if enabled)
            const float *harmonicInput = input;
            const float *percussiveInput = input;

            if (useHPS_ && currentSpeed_ < 0.3f)
            {
                if (!hpSeparator_)
                {
                    hpSeparator_ = std::make_unique<HarmonicPercussiveSeparator>(
                        2048, sampleRate_);
                }

                // Separate into harmonic and percussive components
                hpSeparator_->separateWithOverlap(
                    input, inputSamples,
                    harmonicBuffer_.data(), percussiveBuffer_.data());

                harmonicInput = harmonicBuffer_.data();
                percussiveInput = percussiveBuffer_.data();
            }

            // Step 2: Process harmonic with Phase Vocoder
            int harmonicOut = 0;
            phaseVocoder_->processBlock(
                harmonicInput, inputSamples,
                pvOutputBuffer_.data(), harmonicOut);

            // Step 3: Process percussive with WSOLA
            int percussiveOut = 0;
            wsola_->processBlock(
                percussiveInput, inputSamples,
                wsolaOutputBuffer_.data(), percussiveOut);

            // Step 4: Apply Formant Preservation (if enabled)
            if (useFormants_ && formantPreserver_)
            {
                // Apply formant preservation to harmonic output
                applyFormantPreservation(pvOutputBuffer_.data(), harmonicOut);
            }

            // Step 5: Combine outputs
            outputSamples = std::min(harmonicOut, percussiveOut);

            if (useHPS_)
            {
                // Combine harmonic and percussive
                for (int i = 0; i < outputSamples; ++i)
                {
                    output[i] = pvOutputBuffer_[i] + wsolaOutputBuffer_[i];

                    // Soft clipping to prevent overflow
                    if (output[i] > 0.95f)
                        output[i] = 0.95f;
                    else if (output[i] < -0.95f)
                        output[i] = -0.95f;
                }
            }
            else
            {
                // Just copy PV output (already has transient preservation via WSOLA blend)
                std::copy(pvOutputBuffer_.data(),
                          pvOutputBuffer_.data() + outputSamples,
                          output);
            }
        }

        void HybridStretcherV2::applyFormantPreservation(float *data, int samples)
        {
            if (!formantPreserver_)
            {
                formantPreserver_ = std::make_unique<FormantPreserver>(
                    4096, sampleRate_);
            }

            // Process in frames
            const int frameSize = 2048;
            const int hopSize = frameSize / 2;

            for (int pos = 0; pos + frameSize <= samples; pos += hopSize)
            {
                // Extract frame magnitudes via FFT
                std::vector<float> frame(data + pos, data + pos + frameSize);

                // Apply window
                for (int i = 0; i < frameSize; ++i)
                {
                    float window = 0.5f * (1.0f - std::cos(TWO_PI * i / (frameSize - 1)));
                    frame[i] *= window;
                }

                // TODO: Complete formant preservation logic
                // This would require FFT → extract envelope → apply → IFFT
                // For now, this is a placeholder
            }
        }

        void HybridStretcherV2::applySpectralPeakInterpolation(std::complex<float> *spectrum, int fftSize)
        {
            if (!peakInterpolator_)
            {
                peakInterpolator_ = std::make_unique<SpectralPeakInterpolator>(
                    fftSize, sampleRate_);
            }

            // Extract magnitudes and phases
            int numBins = fftSize / 2 + 1;
            std::vector<float> magnitudes(numBins);
            std::vector<float> phases(numBins);

            for (int k = 0; k < numBins; ++k)
            {
                magnitudes[k] = std::abs(spectrum[k]);
                phases[k] = std::arg(spectrum[k]);
            }

            // Interpolate peaks
            std::vector<float> interpMag, interpPhase;
            peakInterpolator_->interpolatePeaks(magnitudes, phases, interpMag, interpPhase);

            // Reconstruct spectrum with interpolated values
            for (int k = 0; k < numBins; ++k)
            {
                spectrum[k] = std::polar(interpMag[k], interpPhase[k]);
            }
        }

        void HybridStretcherV2::reset()
        {
            if (base_)
                base_->reset();

            if (phaseVocoder_)
                phaseVocoder_->reset();

            if (wsola_)
                wsola_->reset();

            if (hpSeparator_)
                hpSeparator_->reset();

            if (formantPreserver_)
                formantPreserver_->reset();

            if (peakInterpolator_)
                peakInterpolator_->reset();

            // Clear buffers
            std::fill(harmonicBuffer_.begin(), harmonicBuffer_.end(), 0.0f);
            std::fill(percussiveBuffer_.begin(), percussiveBuffer_.end(), 0.0f);
            std::fill(pvOutputBuffer_.begin(), pvOutputBuffer_.end(), 0.0f);
            std::fill(wsolaOutputBuffer_.begin(), wsolaOutputBuffer_.end(), 0.0f);
        }

        int HybridStretcherV2::getLatency() const
        {
            if (phaseVocoder_)
                return phaseVocoder_->getLatency();

            return base_ ? base_->getLatency() : 0;
        }

    } // namespace V2
} // namespace UltraTimeStretch