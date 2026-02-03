#include "UltraTimeStretch_V2_Enhancements.h"

#include <algorithm>

namespace UltraTimeStretch
{
    namespace V2
    {

        EngineV2::EngineV2() : Engine()
        {
            useMultiResolution_ = false;
            useHPSeparation_ = false;
        }

        bool EngineV2::initialize(int sampleRate, int channels, const Options &options)
        {
            const bool ok = Engine::initialize(sampleRate, channels, options);
            if (!ok)
                return false;

            // Minimal/robust: dùng MultiResolutionPV khi UltraQuality.
            // (HP separation bạn có thể bật sau khi file HarmonicPercussiveSeparator.cpp đã ổn định)
            if (options.quality == Quality::UltraQuality)
            {
                useMultiResolution_ = true;
                multiResPV_ = std::make_unique<MultiResolutionPV>(sampleRate, 1.0f);
            }
            else
            {
                useMultiResolution_ = false;
                multiResPV_.reset();
            }

            // Tạm thời tắt để tránh phụ thuộc vào module khác
            useHPSeparation_ = false;
            hpSeparator_.reset();

            return true;
        }

        void EngineV2::setSpeed(float speed)
        {
            Engine::setSpeed(speed);

            if (multiResPV_)
            {
                multiResPV_->setSpeed(speed);
            }

            // Nếu speed cực chậm và trước đó chưa bật multi-res thì bật lên
            if (speed < 0.15f && !useMultiResolution_)
            {
                useMultiResolution_ = true;
                multiResPV_ = std::make_unique<MultiResolutionPV>(getSampleRate(), speed);
            }
        }

        int EngineV2::processV2(const float *input, int inputSamples,
                                float *output, int maxOutputSamples)
        {
            if (!useMultiResolution_ || !multiResPV_)
            {
                return Engine::process(input, inputSamples, output, maxOutputSamples);
            }

            int outSamples = 0;
            multiResPV_->process(input, inputSamples, output, outSamples);
            return std::min(outSamples, maxOutputSamples);
        }

    } // namespace V2
} // namespace UltraTimeStretch