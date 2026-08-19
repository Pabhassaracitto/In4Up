#include <jni.h>
#include <android/log.h>
#include "UltraTimeStretch.h"
#include "UltraTimeStretch_V2_Enhancements.h"

#define LOG_TAG "UltraTimeStretch"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

using namespace UltraTimeStretch;
using namespace UltraTimeStretch::V2;

extern "C"
{

    JNIEXPORT jlong JNICALL
    Java_com_yourcompany_in4up_AudioProcessorFFI_nativeCreate(
        JNIEnv *env, jobject, jint sampleRate, jint channels)
    {

        EngineV2 *engine = new EngineV2();
        Options options;
        options.quality = Quality::HighQuality;
        options.preserveTransients = true;

        if (!engine->initialize(sampleRate, channels, options))
        {
            delete engine;
            return 0;
        }

        LOGD("Engine created: %p", engine);
        return reinterpret_cast<jlong>(engine);
    }

    JNIEXPORT void JNICALL
    Java_com_yourcompany_in4up_AudioProcessorFFI_nativeDestroy(
        JNIEnv *, jobject, jlong enginePtr)
    {

        EngineV2 *engine = reinterpret_cast<EngineV2 *>(enginePtr);
        if (engine)
        {
            engine->shutdown();
            delete engine;
            LOGD("Engine destroyed");
        }
    }

    JNIEXPORT void JNICALL
    Java_com_yourcompany_in4up_AudioProcessorFFI_nativeSetSpeed(
        JNIEnv *, jobject, jlong enginePtr, jfloat speed)
    {

        EngineV2 *engine = reinterpret_cast<EngineV2 *>(enginePtr);
        if (engine)
        {
            engine->setSpeed(speed);
        }
    }

    JNIEXPORT jint JNICALL
    Java_com_yourcompany_in4up_AudioProcessorFFI_nativeProcess(
        JNIEnv *env, jobject, jlong enginePtr,
        jfloatArray inputArray, jint inputFrames,
        jfloatArray outputArray, jint maxOutputFrames)
    {

        EngineV2 *engine = reinterpret_cast<EngineV2 *>(enginePtr);
        if (!engine)
            return 0;

        jfloat *input = (jfloat *)env->GetPrimitiveArrayCritical(inputArray, nullptr);
        jfloat *output = (jfloat *)env->GetPrimitiveArrayCritical(outputArray, nullptr);

        int outputFrames = engine->processV2(input, inputFrames, output, maxOutputFrames);

        env->ReleasePrimitiveArrayCritical(inputArray, input, JNI_ABORT);
        env->ReleasePrimitiveArrayCritical(outputArray, output, 0);

        return outputFrames;
    }

} // extern "C"