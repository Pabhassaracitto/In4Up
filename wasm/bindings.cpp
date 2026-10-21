#include <emscripten/bind.h>
#include "UltraTimeStretch.h"
#include "UltraTimeStretch_V2_Enhancements.h"

using namespace emscripten;
using namespace UltraTimeStretch;
using namespace UltraTimeStretch::V2;

class WasmWrapper
{
public:
    WasmWrapper(int sampleRate, int channels)
    {
        engine = new EngineV2();
        Options options;
        options.quality = Quality::Standard; // Lower for web
        engine->initialize(sampleRate, channels, options);
    }

    ~WasmWrapper()
    {
        if (engine)
        {
            engine->shutdown();
            delete engine;
        }
    }

    void setSpeed(float speed)
    {
        if (engine)
            engine->setSpeed(speed);
    }

    val process(const val &inputArray, int inputFrames, int maxOutputFrames)
    {
        std::vector<float> input = vecFromJSArray<float>(inputArray);
        std::vector<float> output(maxOutputFrames * 2);

        int outputFrames = engine->processV2(
            input.data(), inputFrames,
            output.data(), maxOutputFrames);

        output.resize(outputFrames * 2);
        return val(typed_memory_view(output.size(), output.data()));
    }

private:
    EngineV2 *engine;
};

EMSCRIPTEN_BINDINGS(ultratimestretch)
{
    class_<WasmWrapper>("UltraTimeStretch")
        .constructor<int, int>()
        .function("setSpeed", &WasmWrapper::setSpeed)
        .function("process", &WasmWrapper::process);
}