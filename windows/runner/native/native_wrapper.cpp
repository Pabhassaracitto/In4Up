#include <windows.h>
#include <stdio.h> // <-- THÊM
#include "UltraTimeStretch.h"
#include "UltraTimeStretch_V2_Enhancements.h"

using namespace UltraTimeStretch;
using namespace UltraTimeStretch::V2;

// Helper để ghi log ra file debug
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
        sprintf(buf, "[CreateEngine] sampleRate=%d, channels=%d", sampleRate, channels);
        DebugLog(buf);

        EngineV2 *engine = new EngineV2();
        Options options;
        options.quality = Quality::HighQuality;
        options.preserveTransients = true;

        if (!engine->initialize(sampleRate, channels, options))
        {
            DebugLog("[CreateEngine] initialize FAILED!");
            delete engine;
            return nullptr;
        }

        sprintf(buf, "[CreateEngine] SUCCESS, engine=%p", (void *)engine);
        DebugLog(buf);

        return engine;
    }

    // Option B: Export CreateEngineV2 khớp với Dart FFI (5 tham số)
    __declspec(dllexport) void *CreateEngineV2(int sampleRate, int channels, int quality, char preserveTransients, char preserveFormants)
    {
        char buf[256];
        sprintf(buf, "[CreateEngineV2] sampleRate=%d, channels=%d, quality=%d", sampleRate, channels, quality);
        DebugLog(buf);

        EngineV2 *engine = new EngineV2();
        Options options;
        // Map int từ Dart sang Enum/Bool của C++
        options.quality = static_cast<Quality>(quality);
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
        EngineV2 *engine = static_cast<EngineV2 *>(enginePtr);
        if (engine)
        {
            engine->shutdown();
            delete engine;
        }
    }

    __declspec(dllexport) void SetSpeed(void *enginePtr, float speed)
    {
        char buf[128];
        sprintf(buf, "[SetSpeed] speed=%.3f", speed);
        DebugLog(buf);

        EngineV2 *engine = static_cast<EngineV2 *>(enginePtr);
        if (engine)
        {
            engine->setSpeed(speed);
        }
    }

    __declspec(dllexport) int ProcessAudio(void *enginePtr, float *input, int inputFrames,
                                           float *output, int maxOutputFrames)
    {
        EngineV2 *engine = static_cast<EngineV2 *>(enginePtr);
        if (!engine)
        {
            DebugLog("[ProcessAudio] engine is NULL!");
            return 0;
        }

        int result = engine->processV2(input, inputFrames, output, maxOutputFrames);

        // Log mỗi 100 lần để không spam
        static int callCount = 0;
        if (++callCount % 100 == 0)
        {
            char buf[256];
            sprintf(buf, "[ProcessAudio] inputFrames=%d, maxOutput=%d, result=%d",
                    inputFrames, maxOutputFrames, result);
            DebugLog(buf);
        }

        return result;
    }

} // extern "C"