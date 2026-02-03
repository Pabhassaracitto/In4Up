// UltraTimeStretch_V2_Enhancements.h
// V2 declarations for multi-platform Flutter (Windows/Android/iOS/Web)

#ifndef ULTRA_TIME_STRETCH_V2_H
#define ULTRA_TIME_STRETCH_V2_H

#ifdef _WIN32
// Prevent Windows headers defining min/max macros later
#ifndef NOMINMAX
#define NOMINMAX
#endif
#endif

#include "UltraTimeStretch.h"

#include <map>
#include <string>
#include <vector>
#include <memory>
#include <complex>
#include <algorithm>

#ifdef _WIN32
// Windows SDK may define these macros (rpcndr.h / windows.h)
#ifdef small
#undef small
#endif
#ifdef min
#undef min
#endif
#ifdef max
#undef max
#endif
#endif

namespace UltraTimeStretch
{
    namespace V2
    {

        //==============================================================================
        // Adaptive FFT Manager (ok to keep header-only: small, static, no state)
        //==============================================================================
        class AdaptiveFFTManager
        {
        public:
            struct FFTConfig
            {
                int size;
                int hopDivisor;
                int overlapFactor;
                float qualityScore;
            };

            static FFTConfig getOptimalConfig(float speed, Quality quality);
        };

        //==============================================================================
        // Multi-Resolution Phase Vocoder
        //==============================================================================
        class MultiResolutionPV
        {
        public:
            struct Resolution
            {
                std::unique_ptr<PhaseVocoder> processor;
                int fftSize = 0;
                int hopSize = 0; // IMPORTANT: MultiResolutionPV.cpp expects this
                float weight = 0.0f;
            };

            MultiResolutionPV(int sampleRate, float speed);
            ~MultiResolutionPV() = default;

            void initializeResolutions(float speed);
            void setSpeed(float speed);

            // Some implementations use options/smoothing/info:
            void setOptions(const Options &options);
            int getLatency() const;
            std::string getInfo() const;

            void process(const float *input, int inputSamples, float *output, int &outputSamples);
            void reset();

        private:
            int sampleRate_ = 44100;
            float currentSpeed_ = 1.0f; // IMPORTANT: your .cpp references this
            Options options_{};
            std::vector<Resolution> resolutions_;

            void applySmoothing(float *output, int samples) const; // if your .cpp uses it
        };

        //==============================================================================
        // Harmonic / Percussive Separator
        //==============================================================================
        class HarmonicPercussiveSeparator
        {
        public:
            HarmonicPercussiveSeparator(int fftSize, int sampleRate);
            ~HarmonicPercussiveSeparator() = default;

            void separate(const float *input, int numSamples, float *harmonic, float *percussive);
            void setMedianFilterLengths(int harmonicLength, int percussiveLength);
            void reset();

        private:
            int fftSize_ = 0;
            int sampleRate_ = 44100;
            std::unique_ptr<FFTProcessor> fft_;
            std::vector<float> harmonicMask_;
            std::vector<float> percussiveMask_;
            std::vector<std::vector<float>> spectrogram_;
            int spectrogramPos_ = 0;

            int harmonicMedianLength_ = 0;
            int percussiveMedianLength_ = 0;
        };

        //==============================================================================
        // Spectral Peak Interpolator
        //==============================================================================
        class SpectralPeakInterpolator
        {
        public:
            SpectralPeakInterpolator(int fftSize, int sampleRate);
            ~SpectralPeakInterpolator() = default;

            void interpolatePeaks(const std::vector<float> &magnitudes,
                                  const std::vector<float> &phases,
                                  std::vector<float> &refinedFrequencies,
                                  std::vector<float> &refinedMagnitudes);

            void setPeakThreshold(float threshold);
            int getNumPeaks() const { return numPeaks_; }
            float getPeakFrequency(int index) const;
            void reset();

        private:
            int fftSize_ = 0;
            int sampleRate_ = 44100;
            float peakThreshold_ = 0.0f;
            int numPeaks_ = 0;

            std::vector<float> previousPhases_;
            std::vector<float> peakFrequencies_;
            std::vector<float> peakPhases_;
        };

        //==============================================================================
        // Formant Preserver
        //==============================================================================
        class FormantPreserver
        {
        public:
            FormantPreserver(int fftSize, int sampleRate);
            ~FormantPreserver() = default;

            void extractEnvelope(const std::vector<float> &magnitudes, std::vector<float> &envelope);
            void applyEnvelope(std::vector<float> &magnitudes, const std::vector<float> &targetEnvelope);
            void preserveFormants(std::vector<float> &magnitudes, const std::vector<float> &originalMagnitudes);

            void setPreservationStrength(float strength);
            void reset();

        private:
            int fftSize_ = 0;
            int sampleRate_ = 44100;
            float preservationStrength_ = 0.0f;
            int quefrencyThreshold_ = 0;

            std::unique_ptr<FFTProcessor> fft_;
            std::vector<std::complex<float>> cepstrum_;
            std::vector<float> logMagnitudes_;
            std::vector<float> envelope_;

            void cepstralLiftering(const std::vector<float> &magnitudes, std::vector<float> &envelope);
            void smoothEnvelope(std::vector<float> &envelope);
        };

        //==============================================================================
        // Engine V2
        //==============================================================================
        class EngineV2 : public Engine
        {
        public:
            EngineV2();
            ~EngineV2() = default;

            bool initialize(int sampleRate, int channels, const Options &options);
            void setSpeed(float speed);

            int processV2(const float *input, int inputSamples, float *output, int maxOutputSamples);

            void setFormantPreservation(bool enable);
            void setHarmonicPercussiveSeparation(bool enable);
            void setSpectralPeakInterpolation(bool enable);

            std::string getV2FeaturesInfo() const;

        private:
            bool useMultiResolution_ = false;
            bool useHPSeparation_ = false;
            bool useFormantPreservation_ = false;
            bool usePeakInterpolation_ = false;

            std::unique_ptr<MultiResolutionPV> multiResPV_;
            std::unique_ptr<HarmonicPercussiveSeparator> hpSeparator_;
            std::unique_ptr<FormantPreserver> formantPreserver_;
            std::unique_ptr<SpectralPeakInterpolator> peakInterpolator_;
        };

    } // namespace V2
} // namespace UltraTimeStretch

#endif // ULTRA_TIME_STRETCH_V2_H