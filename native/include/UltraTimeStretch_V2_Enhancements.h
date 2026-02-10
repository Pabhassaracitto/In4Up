// UltraTimeStretch_V2_Enhancements.h
// V2 declarations for multi-platform Flutter (Windows/Android/iOS/Web)
// 1935050226 cập nhật để chạy 3 option

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
#include <thread>
#include <chrono>

#ifdef __ANDROID__
#include <oboe/Oboe.h>
#endif

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
            std::vector<std::vector<float>> resOutputBuffers_; // Pre-allocated buffers

            void applySmoothing(float *output, int samples) const; // if your .cpp uses it
        };

        //==============================================================================
        // Harmonic / Percussive Separator
        //==============================================================================
        class HarmonicPercussiveSeparator
        {
        public:
            HarmonicPercussiveSeparator(int fftSize, int sampleRate);
            ~HarmonicPercussiveSeparator();

            // Median filter kernel sizes
            void setMedianLengths(int harmonicLength, int percussiveLength);

            // Separate one frame (numSamples should be fftSize_)
            void separate(const float *input, int numSamples,
                          float *harmonic, float *percussive);

            // Separate arbitrary length input using overlap-add STFT
            void separateWithOverlap(const float *input, int numSamples,
                                     float *harmonic, float *percussive);

            void reset();

            // Query masks for a specific bin (0..1)
            float getHarmonicRatio(int binIndex) const;
            float getPercussiveRatio(int binIndex) const;

        private:
            float computeMedian(std::vector<float> &values);
            void updateSpectrogram(const std::complex<float> *spectrum);
            void computeMasks();

            int fftSize_;
            int sampleRate_;

            std::unique_ptr<FFTProcessor> fft_;

            std::vector<float> harmonicMask_;
            std::vector<float> percussiveMask_;

            // Spectrogram time buffer
            int spectrogramFrames_;
            std::vector<std::vector<float>> spectrogram_;
            int spectrogramPos_;

            // Temp spectra
            std::vector<std::complex<float>> harmonicSpectrum_;
            std::vector<std::complex<float>> percussiveSpectrum_;

            // Kernel sizes
            int harmonicMedianLength_;
            int percussiveMedianLength_;
        };

        //==============================================================================
        // Spectral Peak Interpolator
        //==============================================================================
        class SpectralPeakInterpolator
        {
        public:
            SpectralPeakInterpolator(int fftSize, int sampleRate);
            ~SpectralPeakInterpolator() = default;

            void setPeakThreshold(float threshold);

            // Peak detect + interpolate (magnitude/phase)
            void interpolatePeaks(const std::vector<float> &magnitudes,
                                  const std::vector<float> &phases,
                                  std::vector<float> &interpMag,
                                  std::vector<float> &interpPhase);

            // Rebuild complex spectrum from interpolated mag/phase
            void interpolateSpectrum(std::vector<std::complex<float>> &spectrum,
                                     const std::vector<float> &magnitudes,
                                     const std::vector<float> &phases);

            const std::vector<int> &getPeakIndices() const;
            float getPeakFrequency(int binIndex) const;
            float getPeakMagnitude(int binIndex) const;
            bool isPeak(int binIndex) const;

            void reset();

            // Advanced helpers (optional use)
            float quadraticInterpolation(float y1, float y2, float y3, float &interpolatedValue) const;

            float estimateFrequencyFromPhase(const std::vector<float> &currentPhases,
                                             const std::vector<float> &previousPhases,
                                             int binIndex, int hopSize) const;

        private:
            void detectPeaks(const std::vector<float> &magnitudes);

            float parabolicInterpolation(float alpha, float beta, float gamma, float &interpolatedMag) const;

        private:
            int fftSize_;
            int sampleRate_;
            int numBins_;

            float peakThreshold_;

            std::vector<float> peakMagnitudes_;
            std::vector<float> peakPhases_;
            std::vector<float> peakFrequencies_;
            std::vector<uint8_t> isPeak_; // dùng byte cho nhẹ

            std::vector<int> detectedPeaks_;
        };

        //==============================================================================
        // Formant Preserver
        //==============================================================================
        class FormantPreserver
        {
        public:
            FormantPreserver(int fftSize, int sampleRate);
            ~FormantPreserver() = default;

            void setQuefrencyLimit(int samples);          // ~ sampleRate/1000
            void setSmoothingWindowSize(int sizeOdd);     // odd >= 3
            void setPreservationStrength(float strength); // 0..1

            // Advanced metric (optional)
            float estimateVoicedRatio(const std::vector<float> &magnitudes) const;

            // API tương thích rộng (để các phần khác dễ dùng)
            void extractEnvelope(const std::vector<float> &magnitudes, std::vector<float> &envelopeOut);
            void applyEnvelope(std::vector<float> &magnitudes, const std::vector<float> &targetEnvelope);
            void preserveFormants(std::vector<float> &magnitudes, const std::vector<float> &originalMagnitudes);

            // Optional: preserve spectrum while keeping phase
            void preserveFormants(std::vector<std::complex<float>> &spectrum,
                                  const std::vector<float> &originalMagnitudes);

            const std::vector<float> &getEnvelope() const { return smoothedEnvelope_; }

            void reset();

        private:
            void cepstralEnvelope(const std::vector<float> &magnitudes, std::vector<float> &envelopeOut);
            void applySmoothing(const std::vector<float> &input, std::vector<float> &output) const;

            int fftSize_;
            int sampleRate_;

            int quefrencyLimit_;
            int smoothingWindowSize_;
            float preservationStrength_;

            std::unique_ptr<FFTProcessor> fft_;

            // Reuse buffers (performance)
            std::vector<float> envelope_;
            std::vector<float> smoothedEnvelope_;
            std::vector<float> logMagnitude_;
            std::vector<std::complex<float>> workComplex_;
        };
        // New for 3 option 1948050226
        // HybridStretcherV2 - dùng lại HybridStretcher V1 bên trong,
        // nhưng cho phép mở rộng sau này (Peak, Formant, ...).
        // ================================================================
        // HybridStretcherV2 - wrapper dùng lại V1 HybridStretcher
        // ================================================================
        class HybridStretcherV2
        {
        public:
            explicit HybridStretcherV2(int sampleRate);
            ~HybridStretcherV2() = default;

            void setSpeed(float speed);
            void setOptions(const Options &options);
            void process(const float *input, int inputSamples,
                         float *output, int &outputSamples);
            void reset();
            int getLatency() const;

            // V2 Feature toggles
            void enableHarmonicPercussiveSeparation(bool enable) { useHPS_ = enable; }
            void enableFormantPreservation(bool enable) { useFormants_ = enable; }
            void enableSpectralPeakInterpolation(bool enable) { usePeakInterp_ = enable; }

        private:
            int sampleRate_ = 44100;
            float currentSpeed_ = 1.0f;
            Options options_{};

            // Dùng lại engine V1 bên trong (fallback)
            std::unique_ptr<::UltraTimeStretch::HybridStretcher> base_;

            // V2 Enhanced processors
            std::unique_ptr<::UltraTimeStretch::PhaseVocoder> phaseVocoder_;
            std::unique_ptr<::UltraTimeStretch::WSOLAProcessor> wsola_;
            std::unique_ptr<HarmonicPercussiveSeparator> hpSeparator_;
            std::unique_ptr<FormantPreserver> formantPreserver_;
            std::unique_ptr<SpectralPeakInterpolator> peakInterpolator_;

            // Processing buffers
            std::vector<float> harmonicBuffer_;
            std::vector<float> percussiveBuffer_;
            std::vector<float> pvOutputBuffer_;
            std::vector<float> wsolaOutputBuffer_;
            std::vector<float> formantEnvelope_;

            // Feature flags
            bool useHPS_ = false;
            bool useFormants_ = false;
            bool usePeakInterp_ = false;

            // Helper methods
            void initializeProcessors();
            void applyFormantPreservation(float *data, int samples);
            void applySpectralPeakInterpolation(std::complex<float> *spectrum, int fftSize);
        };
        //==============================================================================
        // Engine V2
        //==============================================================================
        // old
        /*
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
        };*/
        // New 3 option
        class EngineV2 : public Engine
        {
        public:
            EngineV2();
            ~EngineV2() = default;

            bool initialize(int sampleRate, int channels, const Options &options); // BỎ override
            void setSpeed(float speed);                                            // BỎ override
            int processV2(const float *input, int inputFrames,
                          float *output, int maxOutputFrames);
            void reset(); // BỎ override
            std::string getActiveEngineInfo() const;

        private:
            enum class ActiveEngine
            {
                V1_Standard, // > 0.5x
                V2_Hybrid,   // 0.15x – 0.5x
                V2_MultiRes  // < 0.15x
            };

            ActiveEngine activeEngine_ = ActiveEngine::V1_Standard;
            float currentSpeed_ = 1.0f;

            // Single-channel processors (mono fallback)
            std::unique_ptr<MultiResolutionPV> multiRes_;
            std::unique_ptr<HybridStretcherV2> hybridV2_;

            // Multi-channel processors
            std::vector<std::unique_ptr<MultiResolutionPV>> multiResPerChannel_;
            std::vector<std::unique_ptr<HybridStretcherV2>> hybridV2PerChannel_;

            // Channel buffers for de-interleaving
            std::vector<std::vector<float>> inputChannelBuffers_;
            std::vector<std::vector<float>> outputChannelBuffers_;

            void switchEngine(float speed);
            void initializeChannelProcessors(int channels);

            // Cross-fade support
            static constexpr int CROSSFADE_LENGTH = 256;
            int crossfadeRemaining_ = 0;
            ActiveEngine previousEngine_ = ActiveEngine::V1_Standard;
            std::vector<float> crossfadeBuffer_;

            int processWithEngine(ActiveEngine engineMode, const float *input, int inputFrames,
                                  float *output, int maxOutputFrames);
        };

        //==============================================================================
        // Lock-Free Ring Buffer (SPSC) - For Real-time Streaming
        //==============================================================================
        template <typename T>
        class LockFreeRingBuffer
        {
        public:
            explicit LockFreeRingBuffer(size_t capacity)
                : buffer_(capacity + 1), capacity_(capacity + 1)
            {
                readPos_.store(0);
                writePos_.store(0);
            }

            size_t write(const T *data, size_t count)
            {
                const size_t currentWrite = writePos_.load(std::memory_order_relaxed);
                const size_t currentRead = readPos_.load(std::memory_order_acquire);

                size_t available = capacity_ - 1 - (currentWrite - currentRead + capacity_) % capacity_;
                if (count > available)
                    count = available;

                for (size_t i = 0; i < count; ++i)
                {
                    buffer_[(currentWrite + i) % capacity_] = data[i];
                }

                writePos_.store((currentWrite + count) % capacity_, std::memory_order_release);
                return count;
            }

            size_t read(T *data, size_t count)
            {
                const size_t currentRead = readPos_.load(std::memory_order_relaxed);
                const size_t currentWrite = writePos_.load(std::memory_order_acquire);

                size_t available = (currentWrite - currentRead + capacity_) % capacity_;
                if (count > available)
                    count = available;

                for (size_t i = 0; i < count; ++i)
                {
                    data[i] = buffer_[(currentRead + i) % capacity_];
                }

                readPos_.store((currentRead + count) % capacity_, std::memory_order_release);
                return count;
            }

            size_t availableRead() const
            {
                const size_t currentRead = readPos_.load(std::memory_order_relaxed);
                const size_t currentWrite = writePos_.load(std::memory_order_acquire);
                return (currentWrite - currentRead + capacity_) % capacity_;
            }

        private:
            std::vector<T> buffer_;
            size_t capacity_;
            std::atomic<size_t> readPos_;
            std::atomic<size_t> writePos_;
        };

        //==============================================================================
        // Streaming Engine - Thread-safe Wrapper
        //==============================================================================
        class StreamingEngine
        {
        public:
            StreamingEngine() : inputRing_(131072), outputRing_(524288)
            {
                tempInput_.resize(4096);
                tempOutput_.resize(4096 * 10);
            }

            ~StreamingEngine() { stop(); }

            void start()
            {
                if (running_)
                    return;
                running_ = true;
                processingThread_ = std::thread([this]()
                                                { this->processThread(); });
            }

            void stop()
            {
                running_ = false;
                if (processingThread_.joinable())
                    processingThread_.join();
            }

            // Audio callback thread (High Priority)
            void audioCallback(float *output, int frames)
            {
                int available = outputRing_.availableRead();
                if (available >= frames)
                {
                    outputRing_.read(output, frames);
                }
                else
                {
                    // Underrun - fade out or zero fill
                    if (available > 0)
                        outputRing_.read(output, available);
                    std::fill(output + available, output + frames, 0.0f);
                }
            }

            EngineV2 &getEngine() { return engine_; }
            LockFreeRingBuffer<float> &getInputRing() { return inputRing_; }

        private:
            void processThread()
            {
                while (running_)
                {
                    if (inputRing_.availableRead() >= processBlockSize_)
                    {
                        inputRing_.read(tempInput_.data(), processBlockSize_);

                        int channels = engine_.getChannels() > 0 ? engine_.getChannels() : 2;
                        int inputFrames = processBlockSize_ / channels;
                        int maxOutputFrames = tempOutput_.size() / channels;

                        int outFrames = engine_.processV2(
                            tempInput_.data(), inputFrames,
                            tempOutput_.data(), maxOutputFrames);

                        outputRing_.write(tempOutput_.data(), outFrames * channels);
                    }
                    else
                    {
                        std::this_thread::sleep_for(std::chrono::microseconds(100));
                    }
                }
            }

            EngineV2 engine_;
            LockFreeRingBuffer<float> inputRing_;
            LockFreeRingBuffer<float> outputRing_;
            std::thread processingThread_;
            std::atomic<bool> running_{false};
            std::vector<float> tempInput_;
            std::vector<float> tempOutput_;
            int processBlockSize_ = 1024;
        };

#ifdef __ANDROID__
        //==============================================================================
        // Android Oboe Integration (Low Latency)
        //==============================================================================
        class OboeAudioDriver : public oboe::AudioStreamDataCallback
        {
        public:
            explicit OboeAudioDriver(StreamingEngine &engine) : engine_(engine) {}

            virtual ~OboeAudioDriver() { close(); }

            bool open(int sampleRate, int channelCount)
            {
                oboe::AudioStreamBuilder builder;
                builder.setDirection(oboe::Direction::Output)
                    ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
                    ->setSharingMode(oboe::SharingMode::Exclusive)
                    ->setFormat(oboe::AudioFormat::Float)
                    ->setChannelCount(channelCount)
                    ->setSampleRate(sampleRate)
                    ->setDataCallback(this);

                oboe::Result result = builder.openStream(stream_);
                return (result == oboe::Result::OK);
            }

            bool start()
            {
                if (!stream_)
                    return false;
                return stream_->requestStart() == oboe::Result::OK;
            }

            void close()
            {
                if (stream_)
                {
                    stream_->close();
                    stream_.reset();
                }
            }

            oboe::DataCallbackResult onAudioReady(
                oboe::AudioStream *oboeStream, void *audioData, int32_t numFrames) override
            {
                float *output = static_cast<float *>(audioData);
                // Pull processed audio from StreamingEngine's ring buffer
                engine_.audioCallback(output, numFrames);
                return oboe::DataCallbackResult::Continue;
            }

        private:
            StreamingEngine &engine_;
            std::shared_ptr<oboe::AudioStream> stream_;
        };
#endif

    } // namespace V2
} // namespace UltraTimeStretch

#endif // ULTRA_TIME_STRETCH_V2_H