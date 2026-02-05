#include "UltraTimeStretch_V2_Enhancements.h"
#include <algorithm>

namespace UltraTimeStretch
{
    namespace V2
    {

        HybridStretcherV2::HybridStretcherV2(int sampleRate)
            : sampleRate_(sampleRate),
              currentSpeed_(1.0f),
              options_{},
              base_(std::make_unique<::UltraTimeStretch::HybridStretcher>(sampleRate))
        {
        }

        void HybridStretcherV2::setSpeed(float speed)
        {
            currentSpeed_ = std::clamp(speed, MIN_SPEED, MAX_SPEED);
            if (base_)
            {
                base_->setSpeed(currentSpeed_);
            }
        }

        void HybridStretcherV2::setOptions(const Options &options)
        {
            options_ = options;
            if (base_)
            {
                base_->setOptions(options_);
            }
        }

        void HybridStretcherV2::process(const float *input, int inputSamples,
                                        float *output, int &outputSamples)
        {
            if (!base_)
            {
                outputSamples = 0;
                return;
            }

            // Dùng lại pipeline HybridStretcher V1 đầy đủ
            base_->process(input, inputSamples, output, outputSamples);

            // TODO: Sau này có thể thêm Peak + Formant ở đây:
            // - Lấy output ra FFT
            // - Gọi V2::SpectralPeakInterpolator + V2::FormantPreserver
            // - IFFT về time-domain
        }

        void HybridStretcherV2::reset()
        {
            if (base_)
            {
                base_->reset();
            }
        }

        int HybridStretcherV2::getLatency() const
        {
            return base_ ? base_->getLatency() : 0;
        }

    } // namespace V2
} // namespace UltraTimeStretch