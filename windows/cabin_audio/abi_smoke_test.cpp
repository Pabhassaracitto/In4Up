#define NOMINMAX
#include <windows.h>
#include <cstdio>

// This test deliberately does not require a sound device or capture consent.
// It tests packaging, exports, and invalid-input paths on a Windows CI runner.
int main(int argc, char** argv) {
  if (argc != 2) return 1;
  HMODULE library = LoadLibraryA(argv[1]);
  if (!library) return 2;
  auto create = reinterpret_cast<void* (*)()>(GetProcAddress(library, "cabin_loopback_create"));
  auto start = reinterpret_cast<int (*)(void*)>(GetProcAddress(library, "cabin_loopback_start"));
  auto rate = reinterpret_cast<int (*)(void*)>(GetProcAddress(library, "cabin_loopback_sample_rate"));
  auto channels = reinterpret_cast<int (*)(void*)>(GetProcAddress(library, "cabin_loopback_channels"));
  auto read = reinterpret_cast<int (*)(void*, float*, int)>(GetProcAddress(library, "cabin_loopback_read"));
  auto destroy = reinterpret_cast<void (*)(void*)>(GetProcAddress(library, "cabin_loopback_destroy"));
  auto overlayCreate = GetProcAddress(library, "cabin_overlay_create");
  auto overlayText = GetProcAddress(library, "cabin_overlay_set_text");
  auto overlayDestroy = GetProcAddress(library, "cabin_overlay_destroy");
  if (!create || !start || !rate || !channels || !read || !destroy ||
      !overlayCreate || !overlayText || !overlayDestroy) return 3;
  float sample = 0;
  if (start(nullptr) >= 0 || rate(nullptr) >= 0 || channels(nullptr) >= 0 ||
      read(nullptr, &sample, 1) >= 0) return 4;
  destroy(nullptr);
  void* session = create();
  if (!session) return 5;
  const bool valid = rate(session) == 0 && channels(session) == 0 &&
                     read(session, &sample, 1) < 0 &&
                     read(session, nullptr, 1) < 0 &&
                     read(session, &sample, 0) < 0;
  destroy(session);
  FreeLibrary(library);
  if (!valid) return 6;
  std::puts("Loopback ABI smoke test passed (no capture device required)");
  return 0;
}
