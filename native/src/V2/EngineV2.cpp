// V2 3 option với multi-channel support
#include "UltraTimeStretch_V2_Enhancements.h"
#include <algorithm>
#include <sstream>

namespace UltraTimeStretch
{
    namespace V2
    {

        EngineV2::EngineV2()
            : Engine(), activeEngine_(ActiveEngine::V1_Standard), currentSpeed_(1.0f)
        {
        }

        bool EngineV2::initialize(int sampleRate, int channels, const Options &options)
        {
            const bool ok = Engine::initialize(sampleRate, channels, options);
            if (!ok)
                return false;

            // Initialize channel buffers
            initializeChannelProcessors(channels);

            activeEngine_ = ActiveEngine::V1_Standard;
            currentSpeed_ = 1.0f;
            return true;
        }

        void EngineV2::initializeChannelProcessors(int channels)
        {
            // Allocate channel buffers for de-interleaving
            const int maxFrames = 65536; // Reasonable buffer size
            inputChannelBuffers_.resize(channels);
            outputChannelBuffers_.resize(channels);

            for (int ch = 0; ch < channels; ++ch)
            {
                inputChannelBuffers_[ch].resize(maxFrames);
                outputChannelBuffers_[ch].resize(maxFrames);
            }

            // Pre-allocate per-channel processors (but don't create yet)
            multiResPerChannel_.resize(channels);
            hybridV2PerChannel_.resize(channels);
        }

        void EngineV2::switchEngine(float speed)
        {
            ActiveEngine newEngine;
            if (speed < 0.15f)
            {
                newEngine = ActiveEngine::V2_MultiRes;
            }
            else if (speed < 0.5f)
            {
                newEngine = ActiveEngine::V2_Hybrid;
            }
            else
            {
                newEngine = ActiveEngine::V1_Standard;
            }

            if (newEngine == activeEngine_)
            {
                return;
            }

            activeEngine_ = newEngine;
            const int sr = getSampleRate();
            const int channels = getChannels();

            switch (activeEngine_)
            {
            case ActiveEngine::V2_MultiRes:
                // Create multi-resolution processors for each channel
                for (int ch = 0; ch < channels; ++ch)
                {
                    if (!multiResPerChannel_[ch])
                    {
                        multiResPerChannel_[ch] = std::make_unique<MultiResolutionPV>(sr, speed);
                    }
                    else
                    {
                        multiResPerChannel_[ch]->setSpeed(speed);
                    }
                }
                break;

            case ActiveEngine::V2_Hybrid:
                // Create hybrid processors for each channel
                for (int ch = 0; ch < channels; ++ch)
                {
                    if (!hybridV2PerChannel_[ch])
                    {
                        hybridV2PerChannel_[ch] = std::make_unique<HybridStretcherV2>(sr);
                    }
                    hybridV2PerChannel_[ch]->setSpeed(speed);
                }
                break;

            case ActiveEngine::V1_Standard:
                // V1 already handled by base Engine class
                break;
            }
        }

        void EngineV2::setSpeed(float speed)
        {
            speed = std::clamp(speed, MIN_SPEED, MAX_SPEED);
            currentSpeed_ = speed;

            // Update base Engine
            Engine::setSpeed(speed);

            // Switch engine if needed
            switchEngine(speed);

            // Update V2 engine speeds
            const int channels = getChannels();
            switch (activeEngine_)
            {
            case ActiveEngine::V2_MultiRes:
                for (int ch = 0; ch < channels; ++ch)
                {
                    if (multiResPerChannel_[ch])
                        multiResPerChannel_[ch]->setSpeed(speed);
                }
                break;

            case ActiveEngine::V2_Hybrid:
                for (int ch = 0; ch < channels; ++ch)
                {
                    if (hybridV2PerChannel_[ch])
                        hybridV2PerChannel_[ch]->setSpeed(speed);
                }
                break;

            default:
                break;
            }
        }

        int EngineV2::processV2(const float *input, int inputFrames,
                                float *output, int maxOutputFrames)
        {
            // For V1 Standard, just use base Engine
            if (activeEngine_ == ActiveEngine::V1_Standard)
            {
                return Engine::processInterleaved(input, inputFrames, output, maxOutputFrames);
            }

            const int channels = getChannels();

            // Mono path - simpler and faster
            if (channels == 1)
            {
                int outFrames = 0;

                switch (activeEngine_)
                {
                case ActiveEngine::V2_MultiRes:
                    if (!multiResPerChannel_[0])
                    {
                        multiResPerChannel_[0] = std::make_unique<MultiResolutionPV>(
                            getSampleRate(), currentSpeed_);
                    }
                    multiResPerChannel_[0]->process(input, inputFrames, output, outFrames);
                    break;

                case ActiveEngine::V2_Hybrid:
                    if (!hybridV2PerChannel_[0])
                    {
                        hybridV2PerChannel_[0] = std::make_unique<HybridStretcherV2>(
                            getSampleRate());
                        hybridV2PerChannel_[0]->setSpeed(currentSpeed_);
                    }
                    hybridV2PerChannel_[0]->process(input, inputFrames, output, outFrames);
                    break;

                default:
                    return Engine::process(input, inputFrames, output, maxOutputFrames);
                }

                return std::min(outFrames, maxOutputFrames);
            }

            // Multi-channel path: de-interleave → process → re-interleave

            // De-interleave
            for (int ch = 0; ch < channels; ++ch)
            {
                for (int i = 0; i < inputFrames; ++i)
                {
                    inputChannelBuffers_[ch][i] = input[i * channels + ch];
                }
            }

            // Process each channel
            int minOutFrames = maxOutputFrames;
            for (int ch = 0; ch < channels; ++ch)
            {
                int outSamples = 0;

                switch (activeEngine_)
                {
                case ActiveEngine::V2_MultiRes:
                    if (!multiResPerChannel_[ch])
                    {
                        multiResPerChannel_[ch] = std::make_unique<MultiResolutionPV>(
                            getSampleRate(), currentSpeed_);
                    }
                    multiResPerChannel_[ch]->process(
                        inputChannelBuffers_[ch].data(), inputFrames,
                        outputChannelBuffers_[ch].data(), outSamples);
                    break;

                case ActiveEngine::V2_Hybrid:
                    if (!hybridV2PerChannel_[ch])
                    {
                        hybridV2PerChannel_[ch] = std::make_unique<HybridStretcherV2>(
                            getSampleRate());
                        hybridV2PerChannel_[ch]->setSpeed(currentSpeed_);
                    }
                    hybridV2PerChannel_[ch]->process(
                        inputChannelBuffers_[ch].data(), inputFrames,
                        outputChannelBuffers_[ch].data(), outSamples);
                    break;

                default:
                    break;
                }

                minOutFrames = std::min(minOutFrames, outSamples);
            }

            // Re-interleave
            for (int i = 0; i < minOutFrames; ++i)
            {
                for (int ch = 0; ch < channels; ++ch)
                {
                    output[i * channels + ch] = outputChannelBuffers_[ch][i];
                }
            }

            return minOutFrames;
        }

        void EngineV2::reset()
        {
            Engine::reset();

            const int channels = getChannels();

            // Reset all channel processors
            for (int ch = 0; ch < channels; ++ch)
            {
                if (multiResPerChannel_[ch])
                    multiResPerChannel_[ch]->reset();
                if (hybridV2PerChannel_[ch])
                    hybridV2PerChannel_[ch]->reset();
            }

            // Clear buffers
            for (auto &buffer : inputChannelBuffers_)
            {
                std::fill(buffer.begin(), buffer.end(), 0.0f);
            }
            for (auto &buffer : outputChannelBuffers_)
            {
                std::fill(buffer.begin(), buffer.end(), 0.0f);
            }
        }

        std::string EngineV2::getActiveEngineInfo() const
        {
            std::stringstream ss;
            ss << "EngineV2 active mode: ";
            switch (activeEngine_)
            {
            case ActiveEngine::V2_MultiRes:
                ss << "MultiResolutionPV (<0.15x)";
                break;
            case ActiveEngine::V2_Hybrid:
                ss << "HybridStretcherV2 (0.15x-0.5x)";
                break;
            case ActiveEngine::V1_Standard:
                ss << "V1 HybridStretcher (>0.5x)";
                break;
            }
            ss << " @ speed=" << currentSpeed_ << "x";
            ss << ", channels=" << getChannels();
            return ss.str();
        }

    } // namespace V2
} // namespace UltraTimeStretch