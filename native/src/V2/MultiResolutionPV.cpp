// MultiResolutionPV.cpp - Multi-Resolution Phase Vocoder for Extreme Slow Stretching

#include "../../include/UltraTimeStretch_V2_Enhancements.h"
#include "../../include/UltraTimeStretch.h"
#include <algorithm>
#include <sstream>
#include <vector>
#include <cmath>

// ---------------- Debug logging ----------------
// Bật bằng cách define UTS_DEBUG hoặc UTS_DEBUG_LOG (qua CMake/NDK/Xcode)
#if defined(UTS_DEBUG) || defined(UTS_DEBUG_LOG)
#if defined(__ANDROID__)
#include <android/log.h>
#include <sstream>
#define UTS_LOG(expr)                                                                        \
    do                                                                                       \
    {                                                                                        \
        std::ostringstream _oss;                                                             \
        _oss << expr;                                                                        \
        __android_log_print(ANDROID_LOG_INFO, "UltraTimeStretch", "%s", _oss.str().c_str()); \
    } while (0)
#else
#include <iostream>
#include <sstream>
#define UTS_LOG(expr)                         \
    do                                        \
    {                                         \
        std::ostringstream _oss;              \
        _oss << expr;                         \
        std::cout << _oss.str() << std::endl; \
    } while (0)
#endif
#else
#define UTS_LOG(expr) \
    do                \
    {                 \
    } while (0)
#endif

namespace UltraTimeStretch
{
    namespace V2
    {

        MultiResolutionPV::MultiResolutionPV(int sampleRate, float speed)
            : sampleRate_(sampleRate),
              currentSpeed_(speed)
        {
            initializeResolutions(speed);
        }

        void MultiResolutionPV::initializeResolutions(float speed)
        {
            resolutions_.clear();

            if (speed < 0.15f)
            {
                // ULTRA SLOW MODE: 3 parallel resolutions

                // Large FFT: 16384
                Resolution resLarge;
                resLarge.fftSize = 16384;
                resLarge.hopSize = 16384 / 16; // 1024
                resLarge.weight = 0.6f;
                resLarge.processor = std::make_unique<PhaseVocoder>(
                    resLarge.fftSize, resLarge.hopSize, sampleRate_);
                resLarge.processor->setTimeStretchRatio(speed);

                ::UltraTimeStretch::Options largeOpts;
                largeOpts.quality = ::UltraTimeStretch::Quality::UltraQuality;
                largeOpts.preserveFormants = true;
                largeOpts.antiAliasing = true;
                resLarge.processor->setOptions(largeOpts);

                UTS_LOG("[MultiResolutionPV] Large:  FFT=" << resLarge.fftSize << ", Hop=" << resLarge.hopSize
                                                           << ", Weight=" << resLarge.weight);

                resolutions_.push_back(std::move(resLarge));

                // Medium FFT: 4096
                Resolution resMedium;
                resMedium.fftSize = 4096;
                resMedium.hopSize = 4096 / 8; // 512
                resMedium.weight = 0.3f;
                resMedium.processor = std::make_unique<PhaseVocoder>(
                    resMedium.fftSize, resMedium.hopSize, sampleRate_);
                resMedium.processor->setTimeStretchRatio(speed);

                Options mediumOpts;
                mediumOpts.quality = Quality::HighQuality;
                mediumOpts.preserveFormants = true;
                resMedium.processor->setOptions(mediumOpts);

                UTS_LOG("[MultiResolutionPV] Medium: FFT=" << resMedium.fftSize << ", Hop=" << resMedium.hopSize
                                                           << ", Weight=" << resMedium.weight);

                resolutions_.push_back(std::move(resMedium));

                // Small FFT: 1024 (transients)
                Resolution resSmall;
                resSmall.fftSize = 1024;
                resSmall.hopSize = 1024 / 4; // 256
                resSmall.weight = 0.1f;
                resSmall.processor = std::make_unique<PhaseVocoder>(
                    resSmall.fftSize, resSmall.hopSize, sampleRate_);
                resSmall.processor->setTimeStretchRatio(speed);

                Options smallOpts;
                smallOpts.quality = Quality::Standard;
                smallOpts.preserveTransients = true;
                resSmall.processor->setOptions(smallOpts);

                UTS_LOG("[MultiResolutionPV] Small:  FFT=" << resSmall.fftSize << ", Hop=" << resSmall.hopSize
                                                           << ", Weight=" << resSmall.weight);

                resolutions_.push_back(std::move(resSmall));

                UTS_LOG("[MultiResolutionPV] Initialized 3 resolutions for speed " << speed << "x");
            }
            else if (speed < 0.3f)
            {
                // SLOW MODE: 2 resolutions

                Resolution resLarge;
                resLarge.fftSize = 8192;
                resLarge.hopSize = 8192 / 8;
                resLarge.weight = 0.7f;
                resLarge.processor = std::make_unique<PhaseVocoder>(
                    resLarge.fftSize, resLarge.hopSize, sampleRate_);
                resLarge.processor->setTimeStretchRatio(speed);

                UTS_LOG("[MultiResolutionPV] Large: FFT=" << resLarge.fftSize << ", Hop=" << resLarge.hopSize
                                                          << ", Weight=" << resLarge.weight);

                resolutions_.push_back(std::move(resLarge));

                Resolution resSmall;
                resSmall.fftSize = 2048;
                resSmall.hopSize = 2048 / 4;
                resSmall.weight = 0.3f;
                resSmall.processor = std::make_unique<PhaseVocoder>(
                    resSmall.fftSize, resSmall.hopSize, sampleRate_);
                resSmall.processor->setTimeStretchRatio(speed);

                UTS_LOG("[MultiResolutionPV] Small: FFT=" << resSmall.fftSize << ", Hop=" << resSmall.hopSize
                                                          << ", Weight=" << resSmall.weight);

                resolutions_.push_back(std::move(resSmall));

                UTS_LOG("[MultiResolutionPV] Initialized 2 resolutions for speed " << speed << "x");
            }
            else
            {
                // NORMAL MODE: single resolution

                Resolution single;
                single.fftSize = 2048;
                single.hopSize = 2048 / 4;
                single.weight = 1.0f;
                single.processor = std::make_unique<PhaseVocoder>(
                    single.fftSize, single.hopSize, sampleRate_);
                single.processor->setTimeStretchRatio(speed);

                Options opts;
                opts.quality = Quality::Standard;
                single.processor->setOptions(opts);

                resolutions_.push_back(std::move(single));

                UTS_LOG("[MultiResolutionPV] Single resolution mode for speed " << speed << "x");
            }

            currentSpeed_ = speed;
        }

        void MultiResolutionPV::setSpeed(float speed)
        {
            speed = std::clamp(speed, MIN_SPEED, MAX_SPEED);

            // Check if we need to re-initialize resolutions (threshold crossing)
            bool needsReinit = false;

            if ((currentSpeed_ < 0.15f && speed >= 0.15f) ||
                (currentSpeed_ >= 0.15f && speed < 0.15f) ||
                (currentSpeed_ < 0.3f && speed >= 0.3f) ||
                (currentSpeed_ >= 0.3f && speed < 0.3f))
            {
                needsReinit = true;
            }

            if (needsReinit)
            {
                UTS_LOG("[MultiResolutionPV] Speed change requires re-init: "
                        << currentSpeed_ << "x -> " << speed << "x");
                initializeResolutions(speed);
                return;
            }

            // Just update existing processors
            for (auto &res : resolutions_)
            {
                res.processor->setTimeStretchRatio(speed);
            }
            currentSpeed_ = speed;
        }

        void MultiResolutionPV::setOptions(const Options &options)
        {
            options_ = options;
            for (auto &res : resolutions_)
            {
                res.processor->setOptions(options);
            }
        }

        void MultiResolutionPV::process(const float *input, int inputSamples,
                                        float *output, int &outputSamples)
        {
            if (resolutions_.empty() || !input || inputSamples <= 0 || !output)
            {
                outputSamples = 0;
                return;
            }

            // SINGLE RESOLUTION PATH
            if (resolutions_.size() == 1)
            {
                resolutions_[0].processor->processBlock(input, inputSamples, output, outputSamples);
                return;
            }

            // MULTI-RESOLUTION PATH
            const float stretch = 1.0f / (std::max)(currentSpeed_, MIN_SPEED);
            const int maxExpectedOut =
                static_cast<int>(inputSamples * stretch * 1.3f) + 8192; // safety margin

            std::vector<std::vector<float>> outputs(resolutions_.size());
            std::vector<int> outSampleCounts(resolutions_.size(), 0);

            for (size_t i = 0; i < resolutions_.size(); ++i)
            {
                outputs[i].assign(maxExpectedOut, 0.0f);
                resolutions_[i].processor->processBlock(
                    input, inputSamples,
                    outputs[i].data(), outSampleCounts[i]);
            }

            outputSamples = *std::min_element(outSampleCounts.begin(), outSampleCounts.end());
            if (outputSamples <= 0)
                return;

            for (int i = 0; i < outputSamples; ++i)
            {
                float blended = 0.0f;
                float totalWeight = 0.0f;

                for (size_t r = 0; r < resolutions_.size(); ++r)
                {
                    const float w = resolutions_[r].weight;
                    blended += outputs[r][i] * w;
                    totalWeight += w;
                }

                output[i] = (totalWeight > 1e-6f) ? (blended / totalWeight) : 0.0f;
            }

            // Optional smoothing (reduce tiny combing artifacts)
            if (outputSamples > 4)
            {
                applySmoothing(output, outputSamples);
            }
        }

        void MultiResolutionPV::applySmoothing(float *output, int samples) const
        {
            // Simple 3-point moving average
            std::vector<float> temp(samples);
            std::copy(output, output + samples, temp.begin());

            // Keep endpoints unchanged
            output[0] = temp[0];
            output[samples - 1] = temp[samples - 1];

            for (int i = 1; i < samples - 1; ++i)
            {
                output[i] = 0.25f * temp[i - 1] + 0.5f * temp[i] + 0.25f * temp[i + 1];
            }
        }

        void MultiResolutionPV::reset()
        {
            for (auto &res : resolutions_)
            {
                res.processor->reset();
            }
        }

        int MultiResolutionPV::getLatency() const
        {
            int maxLatency = 0;
            for (const auto &res : resolutions_)
            {
                maxLatency = (std::max)(maxLatency, res.processor->getLatency());
            }
            return maxLatency;
        }

        std::string MultiResolutionPV::getInfo() const
        {
            std::stringstream ss;
            ss << "MultiResolutionPV Info:\n";
            ss << "  Current Speed: " << currentSpeed_ << "x\n";
            ss << "  Resolutions: " << resolutions_.size() << "\n";

            for (size_t i = 0; i < resolutions_.size(); ++i)
            {
                ss << "    [" << i << "] FFT=" << resolutions_[i].fftSize
                   << ", Hop=" << resolutions_[i].hopSize
                   << ", Weight=" << resolutions_[i].weight << "\n";
            }

            ss << "  Total Latency: " << getLatency() << " samples\n";
            return ss.str();
        }

    } // namespace V2
} // namespace UltraTimeStretch