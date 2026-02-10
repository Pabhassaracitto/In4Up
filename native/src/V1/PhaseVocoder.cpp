// PhaseVocoder.cpp - Heart of Frequency Domain Processing
#include "UltraTimeStretch.h"
#include <algorithm>
#include <cstring>

namespace UltraTimeStretch
{

    PhaseVocoder::PhaseVocoder(int fftSize, int hopSize, int sampleRate)
        : fftSize_(fftSize),
          analysisHop_(hopSize),
          synthesisHop_(hopSize),
          sampleRate_(sampleRate),
          timeStretchRatio_(1.0f),
          pitchShiftRatio_(1.0f),
          analysisPhase_(0.0f),
          synthesisPhase_(0.0f),
          accumulatorReadPos_(0),
          accumulatorWritePos_(0),
          normGain_(1.0f)
    {
        fft_ = std::make_unique<FFTProcessor>(fftSize);
        int numBins = fftSize / 2 + 1;

        // Windows
        analysisWindow_.resize(fftSize);
        synthesisWindow_.resize(fftSize);
        for (int i = 0; i < fftSize; ++i)
        {
            // Hann window
            float w = 0.5f * (1.0f - std::cos(TWO_PI * i / (fftSize - 1)));
            analysisWindow_[i] = w;
            synthesisWindow_[i] = w;
        }

        computeNormalizationGain();

        // Buffers
        inputBuffer_.resize(fftSize, 0.0f);
        outputBuffer_.resize(fftSize * 4, 0.0f);
        frameOutput_.resize(fftSize, 0.0f); // <-- THÊM DÒNG NÀY

        // Spectral data
        spectrum_.resize(fftSize);
        magnitudes_.resize(numBins);
        phases_.resize(numBins);
        previousPhases_.resize(numBins, 0.0f);
        synthesisPhases_.resize(numBins, 0.0f);
        frequencies_.resize(numBins);

        // Peak tracking
        peakIndices_.reserve(numBins / 4);
        peakPhases_.reserve(numBins / 4);

        // Output accumulator
        outputAccumulator_.resize(fftSize * 4, 0.0f);
    }

    PhaseVocoder::~PhaseVocoder() {}

    void PhaseVocoder::setTimeStretchRatio(float ratio)
    {
        timeStretchRatio_ = std::clamp(ratio, 0.05f, 20.0f);
        synthesisHop_ = static_cast<int>(analysisHop_ / timeStretchRatio_);
        if (synthesisHop_ < 1)
            synthesisHop_ = 1;
        computeNormalizationGain();
    }

    void PhaseVocoder::setPitchShiftRatio(float ratio)
    {
        pitchShiftRatio_ = std::clamp(ratio, 0.25f, 4.0f);
    }

    void PhaseVocoder::setOptions(const Options &options)
    {
        options_ = options;
    }

    void PhaseVocoder::reset()
    {
        std::fill(inputBuffer_.begin(), inputBuffer_.end(), 0.0f);
        std::fill(outputBuffer_.begin(), outputBuffer_.end(), 0.0f);
        std::fill(previousPhases_.begin(), previousPhases_.end(), 0.0f);
        std::fill(synthesisPhases_.begin(), synthesisPhases_.end(), 0.0f);
        std::fill(outputAccumulator_.begin(), outputAccumulator_.end(), 0.0f);

        analysisPhase_ = 0.0f;
        synthesisPhase_ = 0.0f;
        accumulatorReadPos_ = 0;
        accumulatorWritePos_ = 0;
    }

    int PhaseVocoder::getLatency() const
    {
        return fftSize_;
    }

    void PhaseVocoder::computeNormalizationGain()
    {
        // Tính COLA normalization factor cho synthesis hop hiện tại
        std::vector<float> olaSum(synthesisHop_, 0.0f);

        // Tích lũy overlap của synthesis windows
        int numOverlaps = (fftSize_ + synthesisHop_ - 1) / synthesisHop_;
        for (int n = -numOverlaps; n <= numOverlaps; ++n)
        {
            int offset = n * synthesisHop_;
            for (int i = 0; i < synthesisHop_; ++i)
            {
                int windowIdx = i - offset;
                if (windowIdx >= 0 && windowIdx < fftSize_)
                {
                    float w = analysisWindow_[windowIdx] * synthesisWindow_[windowIdx];
                    olaSum[i] += w;
                }
            }
        }

        // Tìm normalization factor
        float minSum = *std::min_element(olaSum.begin(), olaSum.end());
        normGain_ = (minSum > 1e-6f) ? (1.0f / minSum) : 1.0f;
    }

    void PhaseVocoder::analyzeFrame(const float *input)
    {
        // Apply analysis window and FFT
        for (int i = 0; i < fftSize_; ++i)
        {
            spectrum_[i] = std::complex<float>(input[i] * analysisWindow_[i], 0.0f);
        }

        fft_->forwardInPlace(spectrum_.data());

        int numBins = fftSize_ / 2 + 1;

        // Extract magnitude and phase
        for (int k = 0; k < numBins; ++k)
        {
            magnitudes_[k] = std::abs(spectrum_[k]);
            phases_[k] = std::arg(spectrum_[k]);
        }
    }

    void PhaseVocoder::processPhases()
    {
        int numBins = fftSize_ / 2 + 1;
        float freqPerBin = static_cast<float>(sampleRate_) / fftSize_;

        for (int k = 0; k < numBins; ++k)
        {
            // Phase difference
            float phaseDiff = phases_[k] - previousPhases_[k];
            previousPhases_[k] = phases_[k];

            // Expected phase advance
            float expectedPhase = TWO_PI * k * analysisHop_ / fftSize_;

            // Phase deviation
            float deviation = phaseDiff - expectedPhase;

            // Wrap to [-PI, PI]
            while (deviation > PI)
                deviation -= TWO_PI;
            while (deviation < -PI)
                deviation += TWO_PI;

            // True frequency
            float trueFreq = freqPerBin * k + (deviation * sampleRate_) / (TWO_PI * analysisHop_);
            frequencies_[k] = trueFreq;

            // Synthesis phase update
            float phaseAdvance = TWO_PI * trueFreq * synthesisHop_ / sampleRate_;
            // An toàn hơn
            float wrapped = std::fmod(synthesisPhases_[k], TWO_PI);
            if (wrapped > PI)
                wrapped -= TWO_PI;
            else if (wrapped < -PI)
                wrapped += TWO_PI;
            synthesisPhases_[k] = wrapped;
        }
    }

    void PhaseVocoder::applyPhaseLocking()
    {
        if (!options_.preserveTransients)
            return;

        int numBins = fftSize_ / 2 + 1;
        peakIndices_.clear();

        // Find spectral peaks
        for (int k = 2; k < numBins - 2; ++k)
        {
            if (magnitudes_[k] > magnitudes_[k - 1] &&
                magnitudes_[k] > magnitudes_[k + 1] &&
                magnitudes_[k] > magnitudes_[k - 2] &&
                magnitudes_[k] > magnitudes_[k + 2])
            {
                peakIndices_.push_back(k);
            }
        }

        // Lock phases to peaks
        for (int peakIdx : peakIndices_)
        {
            float peakPhase = synthesisPhases_[peakIdx];

            // Propagate to nearby bins
            int influence = 4;
            for (int k = std::max(0, peakIdx - influence);
                 k < std::min(numBins, peakIdx + influence + 1); ++k)
            {
                if (k != peakIdx)
                {
                    float expectedPhaseDiff = (phases_[k] - phases_[peakIdx]);
                    synthesisPhases_[k] = peakPhase + expectedPhaseDiff;
                }
            }
        }
    }

    void PhaseVocoder::synthesizeFrame(float *output)
    {
        int numBins = fftSize_ / 2 + 1;

        // Reconstruct spectrum
        for (int k = 0; k < numBins; ++k)
        {
            spectrum_[k] = std::polar(magnitudes_[k], synthesisPhases_[k]);
        }

        // Mirror for negative frequencies
        for (int k = numBins; k < fftSize_; ++k)
        {
            spectrum_[k] = std::conj(spectrum_[fftSize_ - k]);
        }

        // Inverse FFT
        fft_->inverseInPlace(spectrum_.data());

        // Apply synthesis window and copy to output
        for (int i = 0; i < fftSize_; ++i)
        {
            output[i] = spectrum_[i].real() * synthesisWindow_[i] * normGain_;
        }
    }

    void PhaseVocoder::processFrame(const float *input, float *output)
    {
        analyzeFrame(input);
        processPhases();
        applyPhaseLocking();
        synthesizeFrame(output);
    }

    void PhaseVocoder::processBlock(const float *input, int inputSamples,
                                    float *output, int &outputSamples)
    {
        outputSamples = 0;
        int inputPos = 0;

        while (inputPos + fftSize_ <= inputSamples)
        {
            // Process one frame - SỬ DỤNG MEMBER VARIABLE
            processFrame(input + inputPos, frameOutput_.data());

            // Overlap-add to accumulator
            for (int i = 0; i < fftSize_; ++i)
            {
                int pos = (accumulatorWritePos_ + i) % outputAccumulator_.size();
                outputAccumulator_[pos] += frameOutput_[i];
            }

            // Output ready samples
            for (int i = 0; i < synthesisHop_; ++i)
            {
                if (outputSamples < inputSamples * 20)
                { // Safety limit
                    output[outputSamples++] = outputAccumulator_[accumulatorReadPos_];
                    outputAccumulator_[accumulatorReadPos_] = 0.0f;
                    accumulatorReadPos_ = (accumulatorReadPos_ + 1) % outputAccumulator_.size();
                }
            }

            accumulatorWritePos_ = (accumulatorWritePos_ + synthesisHop_) % outputAccumulator_.size();
            inputPos += analysisHop_;
        }
    }

} // namespace UltraTimeStretch