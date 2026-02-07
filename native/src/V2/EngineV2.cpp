// V2 3 option 1941050226
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

            // Chưa tạo multiRes_/hybridV2_ ở đây, sẽ tạo khi cần trong switchEngine
            activeEngine_ = ActiveEngine::V1_Standard;
            currentSpeed_ = 1.0f;
            return true;
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

            switch (activeEngine_)
            {
            case ActiveEngine::V2_MultiRes:
                if (!multiRes_)
                {
                    multiRes_ = std::make_unique<MultiResolutionPV>(sr, speed);
                }
                else
                {
                    multiRes_->setSpeed(speed);
                }
                break;

            case ActiveEngine::V2_Hybrid:
                if (!hybridV2_)
                {
                    hybridV2_ = std::make_unique<HybridStretcherV2>(sr);
                }
                hybridV2_->setSpeed(speed);
                break;

            case ActiveEngine::V1_Standard:
                // V1 HybridStretcher đã nằm trong Engine base (channelProcessors_)
                break;
            }
        }

        void EngineV2::setSpeed(float speed)
        {
            speed = std::clamp(speed, MIN_SPEED, MAX_SPEED);
            currentSpeed_ = speed;

            // Cập nhật Engine V1 (base)
            Engine::setSpeed(speed);

            // Chọn engine phù hợp
            switchEngine(speed);
#if defined(_WIN32) && defined(UTS_DEBUG_LOG)
#include <windows.h>
            static void utsLog(const char *s)
            {
                OutputDebugStringA(s);
                OutputDebugStringA("\n");
            }
#endif
#if defined(_WIN32) && defined(UTS_DEBUG_LOG)
            utsLog("EngineV2 switched mode");
#endif
            // Cập nhật engine V2 hiện tại
            switch (activeEngine_)
            {
            case ActiveEngine::V2_MultiRes:
                if (multiRes_)
                    multiRes_->setSpeed(speed);
                break;
            case ActiveEngine::V2_Hybrid:
                if (hybridV2_)
                    hybridV2_->setSpeed(speed);
                break;
            default:
                break;
            }
        }

        int EngineV2::processV2(const float *input, int inputFrames,
                                float *output, int maxOutputFrames)
        {
            int outFrames = 0;

            switch (activeEngine_)
            {
            case ActiveEngine::V2_MultiRes:
                if (multiRes_)
                {
                    multiRes_->process(input, inputFrames, output, outFrames);
                }
                else
                {
                    // fallback V1
                    outFrames = Engine::process(input, inputFrames, output, maxOutputFrames);
                }
                break;

            case ActiveEngine::V2_Hybrid:
                if (hybridV2_)
                {
                    hybridV2_->process(input, inputFrames, output, outFrames);
                }
                else
                {
                    outFrames = Engine::process(input, inputFrames, output, maxOutputFrames);
                }
                break;

            case ActiveEngine::V1_Standard:
            default:
                outFrames = Engine::process(input, inputFrames, output, maxOutputFrames);
                break;
            }

            return std::min(outFrames, maxOutputFrames);
        }

        void EngineV2::reset()
        {
            Engine::reset();
            if (multiRes_)
                multiRes_->reset();
            if (hybridV2_)
                hybridV2_->reset();
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
            return ss.str();
        }

        int EngineV2::getActiveEngineMode() const
        {
            return static_cast<int>(activeEngine_);
        }

        float EngineV2::getCurrentSpeed() const
        {
            return currentSpeed_;
        }

    } // namespace V2
} // namespace UltraTimeStretch

#if defined(_WIN32)
#define UTS_EXPORT __declspec(dllexport)
#else
#define UTS_EXPORT __attribute__((visibility("default")))
#endif

extern "C"
{
    UTS_EXPORT int GetActiveEngineMode(void *enginePtr)
    {
        auto *engine = static_cast<UltraTimeStretch::V2::EngineV2 *>(enginePtr);
        if (!engine)
            return -1;
        return engine->getActiveEngineMode();
    }

    UTS_EXPORT float GetCurrentSpeed(void *enginePtr)
    {
        auto *engine = static_cast<UltraTimeStretch::V2::EngineV2 *>(enginePtr);
        if (!engine)
            return 1.0f;
        return engine->getCurrentSpeed();
    }
}