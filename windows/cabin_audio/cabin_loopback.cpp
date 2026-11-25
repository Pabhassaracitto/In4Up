#include "cabin_loopback.h"

#define NOMINMAX
#include <windows.h>
#include <audioclient.h>
#include <mmdeviceapi.h>
#include <mmreg.h>
#include <wrl/client.h>

#include <algorithm>
#include <atomic>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <new>
#include <thread>

using Microsoft::WRL::ComPtr;

namespace {
// Errors are deliberately stable ABI values, not HRESULTs. In particular,
// overflow must not silently discard audio while the user thinks it was saved.
constexpr int kInvalid = -1;
constexpr int kUnavailable = -2;
constexpr int kUnsupportedFormat = -3;
constexpr int kCaptureFailed = -4;
constexpr int kOverflow = -5;
constexpr int kAlreadyStarted = -6;
constexpr GUID kFloatSubtype = {0x00000003, 0x0000, 0x0010,
                                {0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71}};

struct Capture {
  std::mutex mutex;
  std::condition_variable ready;
  std::thread worker;
  std::atomic<bool> stop{false};
  bool started = false;
  bool initialized = false;
  int error = 0;
  int rate = 0;
  int channels = 0;
  size_t capacity = 0;  // float samples, not frames
  std::deque<float> queue;

  void completeInitialization(int result, int sample_rate = 0, int channel_count = 0) {
    std::lock_guard<std::mutex> lock(mutex);
    error = result;
    rate = sample_rate;
    channels = channel_count;
    capacity = static_cast<size_t>(sample_rate) * channel_count * 3;
    initialized = true;
    ready.notify_one();
  }

  void fail(int code) {
    std::lock_guard<std::mutex> lock(mutex);
    error = code;
  }
};

bool isFloat32(const WAVEFORMATEX* format) {
  if (format->wBitsPerSample != 32) return false;
  if (format->wFormatTag == WAVE_FORMAT_IEEE_FLOAT) return true;
  if (format->wFormatTag != WAVE_FORMAT_EXTENSIBLE ||
      format->cbSize < sizeof(WAVEFORMATEXTENSIBLE) - sizeof(WAVEFORMATEX)) {
    return false;
  }
  const auto* extended = reinterpret_cast<const WAVEFORMATEXTENSIBLE*>(format);
  return IsEqualGUID(extended->SubFormat, kFloatSubtype) &&
         extended->Samples.wValidBitsPerSample == 32;
}

void captureThread(Capture* capture) {
  const HRESULT com = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  if (FAILED(com)) {
    capture->completeInitialization(kUnavailable);
    return;
  }
  {
    ComPtr<IMMDeviceEnumerator> enumerator;
    ComPtr<IMMDevice> device;
    ComPtr<IAudioClient> client;
    ComPtr<IAudioCaptureClient> reader;
    WAVEFORMATEX* format = nullptr;
    HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
        CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
        reinterpret_cast<void**>(enumerator.GetAddressOf()));
    if (SUCCEEDED(hr)) hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
    if (SUCCEEDED(hr)) hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL,
        nullptr, reinterpret_cast<void**>(client.GetAddressOf()));
    if (SUCCEEDED(hr)) hr = client->GetMixFormat(&format);
    int status = FAILED(hr) ? kUnavailable : 0;
    if (status == 0 && (!isFloat32(format) || format->nChannels == 0 ||
                        format->nChannels > 32 || format->nSamplesPerSec == 0 ||
                        format->nSamplesPerSec > 384000 ||
                        format->nBlockAlign != format->nChannels * sizeof(float))) {
      status = kUnsupportedFormat;
    }
    if (status == 0) {
      hr = client->Initialize(AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_LOOPBACK,
          0, 0, format, nullptr);
      if (SUCCEEDED(hr)) hr = client->GetService(__uuidof(IAudioCaptureClient),
          reinterpret_cast<void**>(reader.GetAddressOf()));
      if (SUCCEEDED(hr)) hr = client->Start();
      if (FAILED(hr)) status = kCaptureFailed;
    }
    const int rate = format ? static_cast<int>(format->nSamplesPerSec) : 0;
    const int channels = format ? static_cast<int>(format->nChannels) : 0;
    CoTaskMemFree(format);
    capture->completeInitialization(status, status == 0 ? rate : 0,
                                    status == 0 ? channels : 0);
    if (status == 0) {
      while (!capture->stop.load()) {
        UINT32 frames = 0;
        hr = reader->GetNextPacketSize(&frames);
        if (FAILED(hr)) { capture->fail(kCaptureFailed); break; }
        while (frames != 0 && !capture->stop.load()) {
          BYTE* data = nullptr;
          DWORD flags = 0;
          UINT32 count = 0;
          hr = reader->GetBuffer(&data, &count, &flags, nullptr, nullptr);
          if (FAILED(hr)) { capture->fail(kCaptureFailed); break; }
          bool overflow = false;
          try {
            std::lock_guard<std::mutex> lock(capture->mutex);
            const size_t count_samples = static_cast<size_t>(count) * channels;
            overflow = count_samples > capture->capacity - capture->queue.size();
            if (!overflow) {
              const float* floats = reinterpret_cast<const float*>(data);
              for (size_t i = 0; i < count_samples; ++i) {
                capture->queue.push_back((flags & AUDCLNT_BUFFERFLAGS_SILENT) ? 0.0f : floats[i]);
              }
            }
          } catch (...) {
            overflow = true;
          }
          const HRESULT release_result = reader->ReleaseBuffer(count);
          if (overflow) { capture->fail(kOverflow); break; }
          if (FAILED(release_result)) { capture->fail(kCaptureFailed); break; }
          hr = reader->GetNextPacketSize(&frames);
          if (FAILED(hr)) { capture->fail(kCaptureFailed); break; }
        }
        {
          std::lock_guard<std::mutex> lock(capture->mutex);
          if (capture->error != 0) break;
        }
        // Polling mode works on pre-Windows 10 1703 loopback too.
        Sleep(10);
      }
      client->Stop();
    }
  }  // COM pointers release before CoUninitialize.
  CoUninitialize();
}
}  // namespace

void* cabin_loopback_create() {
  return new (std::nothrow) Capture();
}

int cabin_loopback_start(void* handle) {
  auto* capture = static_cast<Capture*>(handle);
  if (!capture) return kInvalid;
  std::unique_lock<std::mutex> lock(capture->mutex);
  if (capture->started) return kAlreadyStarted;
  capture->started = true;
  try {
    capture->worker = std::thread(captureThread, capture);
  } catch (...) {
    return kUnavailable;
  }
  capture->ready.wait(lock, [capture] { return capture->initialized; });
  return capture->error;
}

int cabin_loopback_sample_rate(void* handle) {
  auto* capture = static_cast<Capture*>(handle);
  if (!capture) return kInvalid;
  std::lock_guard<std::mutex> lock(capture->mutex);
  return capture->rate;
}

int cabin_loopback_channels(void* handle) {
  auto* capture = static_cast<Capture*>(handle);
  if (!capture) return kInvalid;
  std::lock_guard<std::mutex> lock(capture->mutex);
  return capture->channels;
}

int cabin_loopback_read(void* handle, float* output, int max_frames) {
  auto* capture = static_cast<Capture*>(handle);
  if (!capture || !output || max_frames <= 0) return kInvalid;
  std::lock_guard<std::mutex> lock(capture->mutex);
  if (capture->error != 0) return capture->error;
  if (!capture->initialized || capture->channels == 0) return kInvalid;
  const size_t frames = std::min(static_cast<size_t>(max_frames),
                                  capture->queue.size() / capture->channels);
  const size_t samples = frames * capture->channels;
  for (size_t i = 0; i < samples; ++i) {
    output[i] = capture->queue.front();
    capture->queue.pop_front();
  }
  return static_cast<int>(frames);
}

void cabin_loopback_destroy(void* handle) {
  auto* capture = static_cast<Capture*>(handle);
  if (!capture) return;
  capture->stop.store(true);
  if (capture->worker.joinable()) capture->worker.join();
  delete capture;
}
