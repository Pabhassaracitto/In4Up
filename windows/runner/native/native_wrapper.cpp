#define _CRT_SECURE_NO_WARNINGS
#include <windows.h>
#include <stdio.h>
#include <cstdio>
#include <iostream>

#include "../../../native/include/UltraTimeStretch.h"
#include "../../../native/include/UltraTimeStretch_V2_Enhancements.h"

namespace UTS = UltraTimeStretch;
namespace UTS_V2 = UltraTimeStretch::V2;

static void DebugLog(const char *msg)
{
    FILE *f = fopen("C:\\temp\\ultratimestretch_debug.log", "a");
    if (f)
    {
        fprintf(f, "%s\n", msg);
        fclose(f);
    }
    OutputDebugStringA(msg);
    OutputDebugStringA("\n");
}

extern "C"
{
    __declspec(dllexport) void *CreateEngine(int sampleRate, int channels)
    {
        char buf[256];
        snprintf(buf, sizeof(buf), "[CreateEngine] sampleRate=%d, channels=%d",
                 sampleRate, channels);
        DebugLog(buf);

        UTS_V2::EngineV2 *engine = new UTS_V2::EngineV2();

        // Options ở namespace CHA: UltraTimeStretch::Options
        UTS::Options options;
        options.quality = UTS::Quality::HighQuality;
        options.preserveTransients = true;

        if (!engine->initialize(sampleRate, channels, options))
        {
            DebugLog("[CreateEngine] initialize FAILED!");
            delete engine;
            return nullptr;
        }

        snprintf(buf, sizeof(buf), "[CreateEngine] SUCCESS, engine=%p", (void *)engine);
        DebugLog(buf);
        return engine;
    }

    __declspec(dllexport) void *CreateEngineV2(int sampleRate, int channels,
                                               int quality,
                                               char preserveTransients,
                                               char preserveFormants)
    {
        char buf[256];
        snprintf(buf, sizeof(buf),
                 "[CreateEngineV2] sampleRate=%d, channels=%d, quality=%d",
                 sampleRate, channels, quality);
        DebugLog(buf);

        UTS_V2::EngineV2 *engine = new UTS_V2::EngineV2();

        // Options ở namespace CHA: UltraTimeStretch::Options
        UTS::Options options;
        options.quality = static_cast<UTS::Quality>(quality);
        options.preserveTransients = (preserveTransients != 0);
        options.preserveFormants = (preserveFormants != 0);

        if (!engine->initialize(sampleRate, channels, options))
        {
            DebugLog("[CreateEngineV2] initialize FAILED!");
            delete engine;
            return nullptr;
        }
        return engine;
    }

    __declspec(dllexport) void DestroyEngine(void *enginePtr)
    {
        DebugLog("[DestroyEngine] called");
        UTS_V2::EngineV2 *engine = static_cast<UTS_V2::EngineV2 *>(enginePtr);
        if (engine)
        {
            engine->shutdown();
            delete engine;
        }
    }

    __declspec(dllexport) void SetSpeed(void *enginePtr, float speed)
    {
        char buf[128];
        snprintf(buf, sizeof(buf), "[SetSpeed] speed=%.3f", speed);
        DebugLog(buf);

        UTS_V2::EngineV2 *engine = static_cast<UTS_V2::EngineV2 *>(enginePtr);
        if (engine)
            engine->setSpeed(speed);
    }

    __declspec(dllexport) int ProcessAudio(void *enginePtr,
                                           float *input, int inputFrames,
                                           float *output, int maxOutputFrames)
    {
        UTS_V2::EngineV2 *engine = static_cast<UTS_V2::EngineV2 *>(enginePtr);
        if (!engine)
        {
            DebugLog("[ProcessAudio] engine is NULL!");
            return 0;
        }

        int result = engine->processV2(input, inputFrames, output, maxOutputFrames);

        static int callCount = 0;
        if (++callCount % 100 == 0)
        {
            char buf[256];
            snprintf(buf, sizeof(buf),
                     "[ProcessAudio] inputFrames=%d, maxOutput=%d, result=%d",
                     inputFrames, maxOutputFrames, result);
            DebugLog(buf);
        }
        return result;
    }

} // extern "C"