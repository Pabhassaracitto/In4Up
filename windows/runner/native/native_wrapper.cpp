#include <windows.h>
#include "UltraTimeStretch.h"
#include "UltraTimeStretch_V2_Enhancements.h"

using namespace UltraTimeStretch;
using namespace UltraTimeStretch::V2;

extern "C"
{

    __declspec(dllexport) void *CreateEngine(int sampleRate, int channels)
    {
        EngineV2 *engine = new EngineV2();
        Options options;
        options.quality = Quality::HighQuality;
        options.preserveTransients = true;

        if (!engine->initialize(sampleRate, channels, options))
        {
            delete engine;
            return nullptr;
        }

        return engine;
    }

    __declspec(dllexport) void DestroyEngine(void *enginePtr)
    {
        EngineV2 *engine = static_cast<EngineV2 *>(enginePtr);
        if (engine)
        {
            engine->shutdown();
            delete engine;
        }
    }

    __declspec(dllexport) void SetSpeed(void *enginePtr, float speed)
    {
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
            return 0;

        return engine->processV2(input, inputFrames, output, maxOutputFrames);
    }

} // extern "C"