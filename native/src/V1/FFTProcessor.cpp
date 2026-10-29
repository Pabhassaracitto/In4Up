// FFTProcessor.cpp - Optimized In-Place FFT Implementation
#include "UltraTimeStretch.h"
#include <cstring>
namespace UltraTimeStretch
{

    FFTProcessor::FFTProcessor(int size) : size_(size), log2Size_(0)
    {
        // Calculate log2
        int temp = size;
        while (temp > 1)
        {
            temp >>= 1;
            log2Size_++;
        }

        buildTwiddleFactors();

        // Build bit-reverse table
        bitReverseTable_.resize(size_);
        for (int i = 0; i < size_; ++i)
        {
            int reversed = 0;
            int x = i;
            for (int j = 0; j < log2Size_; ++j)
            {
                reversed = (reversed << 1) | (x & 1);
                x >>= 1;
            }
            bitReverseTable_[i] = reversed;
        }

        // Build Hann window
        window_.resize(size_);
        for (int i = 0; i < size_; ++i)
        {
            window_[i] = 0.5f * (1.0f - std::cos(TWO_PI * i / (size_ - 1)));
        }
    }

    FFTProcessor::~FFTProcessor() {}

    void FFTProcessor::buildTwiddleFactors()
    {
        twiddleFactors_.resize(size_ / 2);
        for (int i = 0; i < size_ / 2; ++i)
        {
            float angle = -TWO_PI * i / size_;
            twiddleFactors_[i] = std::complex<float>(std::cos(angle), std::sin(angle));
        }
    }

    void FFTProcessor::bitReverse(std::complex<float> *data)
    {
        for (int i = 0; i < size_; ++i)
        {
            int j = bitReverseTable_[i];
            if (i < j)
            {
                std::swap(data[i], data[j]);
            }
        }
    }

    void FFTProcessor::forwardInPlace(std::complex<float> *data)
    {
        bitReverse(data);

        for (int s = 1; s <= log2Size_; ++s)
        {
            int m = 1 << s;
            int m2 = m >> 1;
            int twiddleStep = size_ / m;

            for (int k = 0; k < size_; k += m)
            {
                for (int j = 0; j < m2; ++j)
                {
                    std::complex<float> twiddle = twiddleFactors_[j * twiddleStep];
                    std::complex<float> t = twiddle * data[k + j + m2];
                    std::complex<float> u = data[k + j];

                    data[k + j] = u + t;
                    data[k + j + m2] = u - t;
                }
            }
        }
    }

    void FFTProcessor::inverseInPlace(std::complex<float> *data)
    {
        // Conjugate
        for (int i = 0; i < size_; ++i)
        {
            data[i] = std::conj(data[i]);
        }

        // Forward FFT
        forwardInPlace(data);

        // Conjugate and scale
        float scale = 1.0f / size_;
        for (int i = 0; i < size_; ++i)
        {
            data[i] = std::conj(data[i]) * scale;
        }
    }

    void FFTProcessor::forward(const float *input, std::complex<float> *output)
    {
        // Copy real input to complex, applying window
        for (int i = 0; i < size_; ++i)
        {
            output[i] = std::complex<float>(input[i] * window_[i], 0.0f);
        }

        forwardInPlace(output);
    }

    void FFTProcessor::inverse(const std::complex<float> *input, float *output)
    {
        // Copy to work buffer
        std::vector<std::complex<float>> work(input, input + size_);

        inverseInPlace(work.data());

        // Extract real part
        for (int i = 0; i < size_; ++i)
        {
            output[i] = work[i].real();
        }
    }

} // namespace UltraTimeStretch