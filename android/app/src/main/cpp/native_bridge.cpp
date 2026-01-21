#include <jni.h>
#include <android/log.h>
#include <string>
#include <memory>
#include <cstring>

#include "UltraTimeStretch.h"

#define LOG_TAG "UltraTimeStretch"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Global engine instance
static std::unique_ptr<UltraTimeStretch::Engine> g_engine = nullptr;

//==============================================================================
// C API for FFI (Dart can call these directly)
//==============================================================================

extern "C" {

// Library version
__attribute__((visibility("default")))
const char* uts_get_version() {
    return "UltraTimeStretch v1.0.0";
}

// Initialize engine
__attribute__((visibility("default")))
int32_t uts_initialize(int32_t sampleRate, int32_t channels, int32_t quality) {
    try {
        if (g_engine) {
            g_engine->shutdown();
        }

        g_engine = std::make_unique<UltraTimeStretch::Engine>();

        UltraTimeStretch::Options options;
        switch (quality) {
            case 0: options.quality = UltraTimeStretch::Quality::Preview; break;
            case 1: options.quality = UltraTimeStretch::Quality::Standard; break;
            case 2: options.quality = UltraTimeStretch::Quality::HighQuality; break;
            case 3: options.quality = UltraTimeStretch::Quality::UltraQuality; break;
            default: options.quality = UltraTimeStretch::Quality::Standard; break;
        }

        options.preserveTransients = true;
        options.antiAliasing = true;
        options.smoothTransitions = true;
        options.transientSensitivity = 0.6f;

        bool success = g_engine->initialize(sampleRate, channels, options);

        if (success) {
            LOGI("Engine initialized: %dHz, %d channels, quality=%d",
                 sampleRate, channels, quality);
        } else {
            LOGE("Failed to initialize engine");
        }

        return success ? 1 : 0;

    } catch (const std::exception& e) {
        LOGE("Exception during initialization: %s", e.what());
        return 0;
    }
}

// Shutdown engine
__attribute__((visibility("default")))
void uts_shutdown() {
    if (g_engine) {
        g_engine->shutdown();
        g_engine.reset();
        LOGI("Engine shutdown");
    }
}

// Set playback speed (0.05 to 10.0)
__attribute__((visibility("default")))
void uts_set_speed(float speed) {
    if (g_engine) {
        g_engine->setSpeed(speed);
        LOGI("Speed set to: %.2fx", speed);
    }
}

// Set pitch shift in semitones (-24 to +24)
__attribute__((visibility("default")))
void uts_set_pitch(float semitones) {
    if (g_engine) {
        g_engine->setPitch(semitones);
        LOGI("Pitch set to: %.1f semitones", semitones);
    }
}

// Process audio buffer (interleaved stereo)
// Returns number of output frames
__attribute__((visibility("default")))
int32_t uts_process(
        const float* inputBuffer,
        int32_t inputFrames,
        float* outputBuffer,
        int32_t maxOutputFrames
) {
    if (!g_engine || !g_engine->isInitialized()) {
        LOGE("Engine not initialized");
        return 0;
    }

    if (!inputBuffer || !outputBuffer || inputFrames <= 0) {
        return 0;
    }

    try {
        int outputFrames = g_engine->processInterleaved(
                inputBuffer, inputFrames,
                outputBuffer, maxOutputFrames
        );

        return outputFrames;

    } catch (const std::exception& e) {
        LOGE("Exception during processing: %s", e.what());
        return 0;
    }
}

// Get current speed
__attribute__((visibility("default")))
float uts_get_speed() {
    if (g_engine) {
        return g_engine->getCurrentSpeed();
    }
    return 1.0f;
}

// Get current pitch
__attribute__((visibility("default")))
float uts_get_pitch() {
    if (g_engine) {
        return g_engine->getCurrentPitch();
    }
    return 0.0f;
}

// Get latency in samples
__attribute__((visibility("default")))
int32_t uts_get_latency() {
    if (g_engine) {
        return g_engine->getLatency();
    }
    return 0;
}

// Reset engine state
__attribute__((visibility("default")))
void uts_reset() {
    if (g_engine) {
        g_engine->reset();
        LOGI("Engine reset");
    }
}

// Flush remaining audio
__attribute__((visibility("default")))
void uts_flush() {
    if (g_engine) {
        g_engine->flush();
    }
}

// Get required output buffer size
__attribute__((visibility("default")))
int32_t uts_get_output_buffer_size(int32_t inputSamples) {
    if (g_engine) {
        return g_engine->getRequiredOutputBufferSize(inputSamples);
    }
    // Worst case: 10x stretch
    return inputSamples * 12;
}

// Check if engine is initialized
__attribute__((visibility("default")))
int32_t uts_is_initialized() {
    return (g_engine && g_engine->isInitialized()) ? 1 : 0;
}

// Get sample rate
__attribute__((visibility("default")))
int32_t uts_get_sample_rate() {
    if (g_engine) {
        return g_engine->getSampleRate();
    }
    return 0;
}

// Get number of channels
__attribute__((visibility("default")))
int32_t uts_get_channels() {
    if (g_engine) {
        return g_engine->getChannels();
    }
    return 0;
}

//==============================================================================
// Batch processing for entire file
//==============================================================================

__attribute__((visibility("default")))
int32_t uts_process_file(
        const float* inputData,
        int32_t totalInputFrames,
        float* outputData,
        int32_t maxOutputFrames,
        float speed,
        int32_t sampleRate,
        int32_t channels
) {
    try {
        // Create temporary engine for file processing
        UltraTimeStretch::Engine tempEngine;

        UltraTimeStretch::Options options;

        // Choose quality based on speed
        if (speed < 0.2f) {
            options.quality = UltraTimeStretch::Quality::UltraQuality;
            options.fftSize = 8192;
        } else if (speed < 0.5f) {
            options.quality = UltraTimeStretch::Quality::HighQuality;
            options.fftSize = 4096;
        } else {
            options.quality = UltraTimeStretch::Quality::Standard;
            options.fftSize = 2048;
        }

        options.preserveTransients = true;
        options.antiAliasing = true;

        if (!tempEngine.initialize(sampleRate, channels, options)) {
            LOGE("Failed to initialize temp engine for file processing");
            return 0;
        }

        tempEngine.setSpeed(speed);

        // Process in chunks
        const int chunkSize = 4096;
        int inputPos = 0;
        int outputPos = 0;

        while (inputPos < totalInputFrames && outputPos < maxOutputFrames) {
            int framesToProcess = std::min(chunkSize, totalInputFrames - inputPos);
            int maxOutputChunk = maxOutputFrames - outputPos;

            int outputFrames = tempEngine.processInterleaved(
                    inputData + inputPos * channels,
                    framesToProcess,
                    outputData + outputPos * channels,
                    maxOutputChunk
            );

            inputPos += framesToProcess;
            outputPos += outputFrames;
        }

        // Flush remaining
        tempEngine.flush();

        LOGI("File processed: %d input frames -> %d output frames at %.2fx speed",
             totalInputFrames, outputPos, speed);

        return outputPos;

    } catch (const std::exception& e) {
        LOGE("Exception during file processing: %s", e.what());
        return 0;
    }
}

} // extern "C"

//==============================================================================
// JNI Interface for Kotlin/Java
//==============================================================================

extern "C"
JNIEXPORT jstring JNICALL
Java_com_ultramusic_player_UltraTimeStretchEngine_getVersion(
        JNIEnv* env,
        jobject /* this */
) {
    return env->NewStringUTF(uts_get_version());
}

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_ultramusic_player_UltraTimeStretchEngine_initialize(
        JNIEnv* env,
        jobject /* this */,
        jint sampleRate,
        jint channels,
        jint quality
) {
    return uts_initialize(sampleRate, channels, quality) == 1;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_ultramusic_player_UltraTimeStretchEngine_shutdown(
        JNIEnv* env,
jobject /* this */
) {
uts_shutdown();
}

extern "C"
JNIEXPORT void JNICALL
Java_com_ultramusic_player_UltraTimeStretchEngine_setSpeed(
        JNIEnv* env,
jobject /* this */,
jfloat speed
) {
uts_set_speed(speed);
}

extern "C"
JNIEXPORT jint JNICALL
        Java_com_ultramusic_player_UltraTimeStretchEngine_processAudio(
        JNIEnv* env,
        jobject /* this */,
        jfloatArray inputArray,
jfloatArray outputArray
) {
jsize inputLength = env->GetArrayLength(inputArray);
jsize outputLength = env->GetArrayLength(outputArray);

jfloat* inputBuffer = env->GetFloatArrayElements(inputArray, nullptr);
jfloat* outputBuffer = env->GetFloatArrayElements(outputArray, nullptr);

if (!inputBuffer || !outputBuffer) {
if (inputBuffer) env->ReleaseFloatArrayElements(inputArray, inputBuffer, 0);
if (outputBuffer) env->ReleaseFloatArrayElements(outputArray, outputBuffer, 0);
return 0;
}

int channels = uts_get_channels();
if (channels == 0) channels = 2;

int inputFrames = inputLength / channels;
int maxOutputFrames = outputLength / channels;

int outputFrames = uts_process(inputBuffer, inputFrames, outputBuffer, maxOutputFrames);

env->ReleaseFloatArrayElements(inputArray, inputBuffer, 0);
env->ReleaseFloatArrayElements(outputArray, outputBuffer, 0);

return outputFrames * channels;
}