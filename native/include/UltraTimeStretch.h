#ifndef ULTRA_TIME_STRETCH_H
#define ULTRA_TIME_STRETCH_H

#include <cstdint>
#include <memory>
#include <vector>
#include <complex>
#include <cmath>
#include <algorithm>
#include <atomic>

// SIMD Detection
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    #define UTS_USE_NEON 1
    #include <arm_neon.h>
#elif defined(__SSE2__)
    #define UTS_USE_SSE 1
    #include <emmintrin.h>
    #if defined(__AVX__)
        #define UTS_USE_AVX 1
        #include <immintrin.h>
    #endif
#endif

namespace UltraTimeStretch {

//==============================================================================
// Configuration Constants
//==============================================================================
constexpr int MAX_FFT_SIZE = 8192;
constexpr int MIN_FFT_SIZE = 256;
constexpr int MAX_CHANNELS = 8;
constexpr float MIN_SPEED = 0.05f;
constexpr float MAX_SPEED = 10.0f;
constexpr float PI = 3.14159265358979323846f;
constexpr float TWO_PI = 2.0f * PI;

//==============================================================================
// Quality Modes
//==============================================================================
enum class Quality {
    Preview,        // Lowest latency, acceptable quality
    Standard,       // Balanced
    HighQuality,    // Better quality, higher latency
    UltraQuality,   // Best quality for extreme stretching (0.1x)
    Realtime        // Optimized for live performance
};

//==============================================================================
// Processing Options
//==============================================================================
struct Options {
    Quality quality = Quality::Standard;
    bool preserveTransients = true;
    bool preserveFormants = false;
    bool antiAliasing = true;
    bool smoothTransitions = true;
    int fftSize = 2048;            // Will be auto-adjusted based on speed
    int overlapFactor = 4;          // Higher = better quality, more CPU
    float transientSensitivity = 0.5f;  // 0.0 - 1.0
};

//==============================================================================
// Circular Buffer Template
//==============================================================================
template<typename T>
class CircularBuffer {
public:
    CircularBuffer(size_t capacity = 65536) 
        : buffer_(capacity), capacity_(capacity), readPos_(0), writePos_(0), size_(0) {}
    
    void resize(size_t newCapacity) {
        buffer_.resize(newCapacity);
        capacity_ = newCapacity;
        clear();
    }
    
    void clear() {
        readPos_ = writePos_ = size_ = 0;
        std::fill(buffer_.begin(), buffer_.end(), T(0));
    }
    
    size_t write(const T* data, size_t count) {
        count = std::min(count, capacity_ - size_);
        for (size_t i = 0; i < count; ++i) {
            buffer_[writePos_] = data[i];
            writePos_ = (writePos_ + 1) % capacity_;
        }
        size_ += count;
        return count;
    }
    
    size_t read(T* data, size_t count) {
        count = std::min(count, size_);
        for (size_t i = 0; i < count; ++i) {
            data[i] = buffer_[readPos_];
            readPos_ = (readPos_ + 1) % capacity_;
        }
        size_ -= count;
        return count;
    }
    
    T peek(size_t offset) const {
        return buffer_[(readPos_ + offset) % capacity_];
    }
    
    size_t available() const { return size_; }
    size_t space() const { return capacity_ - size_; }
    bool isEmpty() const { return size_ == 0; }
    
private:
    std::vector<T> buffer_;
    size_t capacity_;
    size_t readPos_, writePos_, size_;
};

//==============================================================================
// FFT Processor - Optimized In-Place FFT
//==============================================================================
class FFTProcessor {
public:
    FFTProcessor(int size);
    ~FFTProcessor();
    
    void forward(const float* input, std::complex<float>* output);
    void inverse(const std::complex<float>* input, float* output);
    
    // In-place complex FFT
    void forwardInPlace(std::complex<float>* data);
    void inverseInPlace(std::complex<float>* data);
    
    int getSize() const { return size_; }
    
private:
    void buildTwiddleFactors();
    void bitReverse(std::complex<float>* data);
    
    int size_;
    int log2Size_;
    std::vector<std::complex<float>> twiddleFactors_;
    std::vector<int> bitReverseTable_;
    std::vector<float> window_;
};

//==============================================================================
// Transient Detector - Preserves Attacks and Percussive Elements
//==============================================================================
class TransientDetector {
public:
    TransientDetector(int sampleRate = 44100);
    
    void setSensitivity(float sensitivity);
    void process(const float* input, int numSamples);
    
    bool isTransient(int sampleIndex) const;
    float getTransientStrength(int sampleIndex) const;
    const std::vector<int>& getTransientPositions() const { return transientPositions_; }
    
    void reset();
    
private:
    float computeSpectralFlux(const float* frame, int size);
    float computeOnsetStrength(const float* frame, int size);
    
    int sampleRate_;
    float sensitivity_;
    float threshold_;
    float adaptiveThreshold_;
    
    std::vector<float> previousSpectrum_;
    std::vector<float> transientStrength_;
    std::vector<int> transientPositions_;
    std::vector<float> onsetFunction_;
    
    std::unique_ptr<FFTProcessor> fft_;
    std::vector<std::complex<float>> spectrum_;
};

//==============================================================================
// Phase Vocoder Core - Heart of Frequency Domain Processing
//==============================================================================
class PhaseVocoder {
public:
    PhaseVocoder(int fftSize, int hopSize, int sampleRate);
    ~PhaseVocoder();
    
    void setTimeStretchRatio(float ratio);
    void setPitchShiftRatio(float ratio);
    void setOptions(const Options& options);
    
    void processFrame(const float* input, float* output);
    void processBlock(const float* input, int inputSamples, 
                      float* output, int& outputSamples);
    
    void reset();
    
    int getLatency() const;
    int getFftSize() const { return fftSize_; }
    int getHopSize() const { return analysisHop_; }
    
private:
    void analyzeFrame(const float* input);
    void synthesizeFrame(float* output);
    void processPhases();
    void applyPhaseLocking();
    void preserveTransients(const float* input);
    
    int fftSize_;
    int analysisHop_;
    int synthesisHop_;
    int sampleRate_;
    
    float timeStretchRatio_;
    float pitchShiftRatio_;
    
    std::unique_ptr<FFTProcessor> fft_;
    
    // Analysis buffers
    std::vector<float> analysisWindow_;
    std::vector<float> synthesisWindow_;
    std::vector<float> inputBuffer_;
    std::vector<float> outputBuffer_;
    
    // Spectral data
    std::vector<std::complex<float>> spectrum_;
    std::vector<float> magnitudes_;
    std::vector<float> phases_;
    std::vector<float> previousPhases_;
    std::vector<float> synthesisPhases_;
    std::vector<float> frequencies_;
    
    // Phase locking
    std::vector<int> peakIndices_;
    std::vector<float> peakPhases_;
    
    // Accumulator for overlap-add
    std::vector<float> outputAccumulator_;
    int accumulatorReadPos_;
    int accumulatorWritePos_;
    
    float analysisPhase_;
    float synthesisPhase_;
    
    Options options_;
};

//==============================================================================
// WSOLA Processor - For Transient Preservation
//==============================================================================
class WSOLAProcessor {
public:
    WSOLAProcessor(int frameSize, int sampleRate);
    ~WSOLAProcessor();
    
    void setTimeStretchRatio(float ratio);
    void processBlock(const float* input, int inputSamples,
                      float* output, int& outputSamples);
    
    void reset();
    
private:
    int findBestOffset(const float* current, const float* previous, 
                       int searchRange);
    float computeCorrelation(const float* a, const float* b, int length);
    
    int frameSize_;
    int overlapSize_;
    int sampleRate_;
    float ratio_;
    
    std::vector<float> previousFrame_;
    std::vector<float> overlapBuffer_;
    std::vector<float> window_;
    
    float inputPosition_;
    int searchRange_;
};

//==============================================================================
// Hybrid Time Stretcher - Combines Phase Vocoder + WSOLA
//==============================================================================
class HybridStretcher {
public:
    HybridStretcher(int sampleRate = 44100);
    ~HybridStretcher();
    
    void setSpeed(float speed);
    void setOptions(const Options& options);
    
    void process(const float* input, int inputSamples,
                 float* output, int& outputSamples);
    
    void processInterleaved(const float* input, int inputFrames, int channels,
                            float* output, int& outputFrames);
    
    void reset();
    
    int getLatency() const;
    float getCurrentSpeed() const { return currentSpeed_; }
    
private:
    void initializeForSpeed(float speed);
    void blendOutputs(const float* pvOutput, const float* wsolaOutput,
                      const float* transientMask, float* output, int samples);
    
    int sampleRate_;
    float currentSpeed_;
    float targetSpeed_;
    Options options_;
    
    std::unique_ptr<PhaseVocoder> phaseVocoder_;
    std::unique_ptr<WSOLAProcessor> wsola_;
    std::unique_ptr<TransientDetector> transientDetector_;
    
    // Blend buffers
    std::vector<float> pvBuffer_;
    std::vector<float> wsolaBuffer_;
    std::vector<float> blendMask_;
    
    bool needsReinit_;
};

//==============================================================================
// Main Engine - Public API
//==============================================================================
class Engine {
public:
    Engine();
    ~Engine();
    
    // Initialization
    bool initialize(int sampleRate, int channels, const Options& options = Options());
    void shutdown();
    bool isInitialized() const { return initialized_; }
    
    // Configuration
    void setSpeed(float speed);          // 0.1 to 10.0
    void setPitch(float semitones);      // -24 to +24
    void setOptions(const Options& options);
    
    // Processing
    int process(const float* input, int inputSamples, 
                float* output, int maxOutputSamples);
    
    int processInterleaved(const float* input, int inputFrames,
                           float* output, int maxOutputFrames);
    
    // Utilities
    void flush();
    void reset();
    int getLatency() const;
    int getRequiredOutputBufferSize(int inputSamples) const;
    
    // Status
    float getCurrentSpeed() const { return speed_; }
    float getCurrentPitch() const { return pitch_; }
    int getSampleRate() const { return sampleRate_; }
    int getChannels() const { return channels_; }
    
private:
    bool initialized_;
    int sampleRate_;
    int channels_;
    float speed_;
    float pitch_;
    
    Options options_;
    std::vector<std::unique_ptr<HybridStretcher>> channelProcessors_;
    
    // De-interleave buffers
    std::vector<std::vector<float>> inputChannels_;
    std::vector<std::vector<float>> outputChannels_;
    
    CircularBuffer<float> inputBuffer_;
    CircularBuffer<float> outputBuffer_;
};

} // namespace UltraTimeStretch

#endif // ULTRA_TIME_STRETCH_H