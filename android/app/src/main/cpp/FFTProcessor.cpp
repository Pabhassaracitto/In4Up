// FFTProcessor.cpp
#include "UltraTimeStretch.h"

namespace UltraTimeStretch {

FFTProcessor::FFTProcessor(int size) 
    : size_(size)
    , log2Size_(0)
{
    // Calculate log2(size)
    int temp = size;
    while (temp > 1) {
        temp >>= 1;
        log2Size_++;
    }
    
    buildTwiddleFactors();
    
    // Build bit-reverse table
    bitReverseTable_.resize(size_);
    for (int i = 0; i < size_; ++i) {
        int j = 0;
        int x = i;
        for (int k = 0; k < log2Size_; ++k) {
            j = (j << 1) | (x & 1);
            x >>= 1;
        }
        bitReverseTable_[i] = j;
    }
    
    // Build Hann window
    window_.resize(size_);
    for (int i = 0; i < size_; ++i) {
        window_[i] = 0.5f * (1.0f - std::cos(TWO_PI * i / size_));
    }
}

FFTProcessor::~FFTProcessor() = default;

void FFTProcessor::buildTwiddleFactors() {
    twiddleFactors_.resize(size_ / 2);
    for (int i = 0; i < size_ / 2; ++i) {
        float angle = -TWO_PI * i / size_;
        twiddleFactors_[i] = std::complex<float>(std::cos(angle), std::sin(angle));
    }
}

void FFTProcessor::bitReverse(std::complex<float>* data) {
    for (int i = 0; i < size_; ++i) {
        int j = bitReverseTable_[i];
        if (i < j) {
            std::swap(data[i], data[j]);
        }
    }
}

void FFTProcessor::forwardInPlace(std::complex<float>* data) {
    bitReverse(data);
    
    // Cooley-Tukey iterative FFT
    for (int stage = 1; stage <= log2Size_; ++stage) {
        int m = 1 << stage;
        int halfM = m >> 1;
        int tableFactor = size_ / m;
        
        for (int k = 0; k < size_; k += m) {
            for (int j = 0; j < halfM; ++j) {
                std::complex<float> twiddle = twiddleFactors_[j * tableFactor];
                std::complex<float> t = twiddle * data[k + j + halfM];
                std::complex<float> u = data[k + j];
                
                data[k + j] = u + t;
                data[k + j + halfM] = u - t;
            }
        }
    }
}

void FFTProcessor::inverseInPlace(std::complex<float>* data) {
    // Conjugate input
    for (int i = 0; i < size_; ++i) {
        data[i] = std::conj(data[i]);
    }
    
    // Forward FFT
    forwardInPlace(data);
    
    // Conjugate and scale
    float scale = 1.0f / size_;
    for (int i = 0; i < size_; ++i) {
        data[i] = std::conj(data[i]) * scale;
    }
}

void FFTProcessor::forward(const float* input, std::complex<float>* output) {
    // Apply window and convert to complex
    for (int i = 0; i < size_; ++i) {
        output[i] = std::complex<float>(input[i] * window_[i], 0.0f);
    }
    forwardInPlace(output);
}

void FFTProcessor::inverse(const std::complex<float>* input, float* output) {
    // Copy to temp buffer for in-place transform
    std::vector<std::complex<float>> temp(input, input + size_);
    inverseInPlace(temp.data());
    
    // Extract real part
    for (int i = 0; i < size_; ++i) {
        output[i] = temp[i].real();
    }
}

} // namespace UltraTimeStretch