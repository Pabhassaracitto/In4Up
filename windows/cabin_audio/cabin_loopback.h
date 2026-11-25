#pragma once

// All functions are synchronous and must be called from the same client
// thread. The capture worker owns its COM apartment and WASAPI interfaces.
// Read returns frames (not samples), zero when no data is ready, or a negative
// error. A negative read is terminal; destroy and create a new session.
#ifdef _WIN32
#define CABIN_EXPORT extern "C" __declspec(dllexport)
#else
#define CABIN_EXPORT extern "C"
#endif

CABIN_EXPORT void* cabin_loopback_create();
CABIN_EXPORT int cabin_loopback_start(void* handle);
CABIN_EXPORT int cabin_loopback_sample_rate(void* handle);
CABIN_EXPORT int cabin_loopback_channels(void* handle);
CABIN_EXPORT int cabin_loopback_read(void* handle, float* output, int max_frames);
CABIN_EXPORT void cabin_loopback_destroy(void* handle);
