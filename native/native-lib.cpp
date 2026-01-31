#include <jni.h>
#include <string>
#include <android/log.h>
#include "UltraTimeStretch.h"
#include "UltraTimeStretch_V2_Enhancements.h"

#define LOG_TAG "UltraTimeStretch"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

using namespace UltraTimeStretch;
using namespace UltraTimeStretch::V2;

extern "C"
{

    // Create engine
    JNIEXPORT jlong JNICALL
    Java_com_yourcompany_vipsound_AudioProcessor_nativeCreate(
        JNIEnv *env, jobject obj, jint sampleRate, jint channels, jboolean useV2)
    {

        LOGD("Creating engine: sampleRate=%d, channels=%d, useV2=%d",
             sampleRate, channels, useV2);

        Options options;
        options.quality = Quality::HighQuality; // NOT Ultra for mobile
        options.preserveTransients = true;

        if (useV2)
        {
            EngineV2 *engine = new EngineV2();
            if (!engine->initialize(sampleRate, channels, options))
            {
                delete engine;
                return 0;
            }
            return reinterpret_cast<jlong>(engine);
        }
        else
        {
            Engine *engine = new Engine();
            if (!engine->initialize(sampleRate, channels, options))
            {
                delete engine;
                return 0;
            }
            return reinterpret_cast<jlong>(engine);
        }
    }

    // Destroy engine
    JNIEXPORT void JNICALL
    Java_com_yourcompany_vipsound_AudioProcessor_nativeDestroy(
        JNIEnv *env, jobject obj, jlong enginePtr, jboolean useV2)
    {

        if (enginePtr == 0)
            return;

        if (useV2)
        {
            EngineV2 *engine = reinterpret_cast<EngineV2 *>(enginePtr);
            engine->shutdown();
            delete engine;
        }
        else
        {
            Engine *engine = reinterpret_cast<Engine *>(enginePtr);
            engine->shutdown();
            delete engine;
        }

        LOGD("Engine destroyed");
    }

    // Set speed
    JNIEXPORT void JNICALL
    Java_com_yourcompany_vipsound_AudioProcessor_nativeSetSpeed(
        JNIEnv *env, jobject obj, jlong enginePtr, jfloat speed, jboolean useV2)
    {

        if (enginePtr == 0)
            return;

        if (useV2)
        {
            EngineV2 *engine = reinterpret_cast<EngineV2 *>(enginePtr);
            engine->setSpeed(speed);
        }
        else
        {
            Engine *engine = reinterpret_cast<Engine *>(enginePtr);
            engine->setSpeed(speed);
        }

        LOGD("Speed set to: %.2f", speed);
    }

    // Process audio
    JNIEXPORT jint JNICALL
    Java_com_yourcompany_vipsound_AudioProcessor_nativeProcess(
        JNIEnv *env, jobject obj, jlong enginePtr,
        jfloatArray inputArray, jint inputFrames,
        jfloatArray outputArray, jint maxOutputFrames,
        jboolean useV2)
    {

        if (enginePtr == 0)
            return 0;

        jfloat *input = env->GetFloatArrayElements(inputArray, nullptr);
        jfloat *output = env->GetFloatArrayElements(outputArray, nullptr);

        int outputFrames = 0;

        if (useV2)
        {
            EngineV2 *engine = reinterpret_cast<EngineV2 *>(enginePtr);
            outputFrames = engine->processV2(input, inputFrames, output, maxOutputFrames);
        }
        else
        {
            Engine *engine = reinterpret_cast<Engine *>(enginePtr);
            outputFrames = engine->processInterleaved(input, inputFrames, output, maxOutputFrames);
        }

        env->ReleaseFloatArrayElements(inputArray, input, JNI_ABORT);
        env->ReleaseFloatArrayElements(outputArray, output, 0);

        return outputFrames;
    }

    // Get latency
    JNIEXPORT jint JNICALL
    Java_com_yourcompany_vipsound_AudioProcessor_nativeGetLatency(
        JNIEnv *env, jobject obj, jlong enginePtr, jboolean useV2)
    {

        if (enginePtr == 0)
            return 0;

        if (useV2)
        {
            EngineV2 *engine = reinterpret_cast<EngineV2 *>(enginePtr);
            return engine->getLatency();
        }
        else
        {
            Engine *engine = reinterpret_cast<Engine *>(enginePtr);
            return engine->getLatency();
        }
    }

} // extern "C"