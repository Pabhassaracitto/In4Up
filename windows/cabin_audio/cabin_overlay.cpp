#define NOMINMAX
#include <windows.h>
#include <windowsx.h>

#include <condition_variable>
#include <mutex>
#include <new>
#include <string>
#include <thread>

#define CABIN_EXPORT extern "C" __declspec(dllexport)

namespace {
constexpr wchar_t kWindowClass[] = L"In4UpCabinCaptionOverlay";
constexpr UINT kCaptionChanged = WM_APP + 17;
constexpr int kExpandedWidth = 300;
constexpr int kExpandedHeight = 120;
constexpr int kCollapsedWidth = 72;
constexpr int kCollapsedHeight = 48;

struct Overlay {
  std::mutex mutex;
  std::condition_variable ready;
  std::thread thread;
  HWND window = nullptr;
  DWORD thread_id = 0;
  bool initialized = false;
  bool collapsed = false;
  bool moving = false;
  bool dragged = false;
  POINT down_screen{};
  POINT down_window{};
  std::wstring caption;
};

LRESULT CALLBACK windowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  auto* overlay = reinterpret_cast<Overlay*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    auto* cs = reinterpret_cast<CREATESTRUCTW*>(lparam);
    overlay = static_cast<Overlay*>(cs->lpCreateParams);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(overlay));
  }
  if (!overlay) return DefWindowProcW(hwnd, message, wparam, lparam);
  switch (message) {
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
    case WM_ERASEBKGND:
      return 1;
    case WM_PAINT: {
      PAINTSTRUCT ps;
      HDC dc = BeginPaint(hwnd, &ps);
      RECT rect;
      GetClientRect(hwnd, &rect);
      HBRUSH background = CreateSolidBrush(RGB(30, 37, 65));
      FillRect(dc, &rect, background);
      DeleteObject(background);
      SetBkMode(dc, TRANSPARENT);
      SetTextColor(dc, RGB(255, 255, 255));
      SelectObject(dc, GetStockObject(DEFAULT_GUI_FONT));
      InflateRect(&rect, -12, -10);
      std::wstring text;
      {
        std::lock_guard<std::mutex> lock(overlay->mutex);
        text = (overlay->collapsed || overlay->caption.empty()) ? L"In4Up" : overlay->caption;
      }
      DrawTextW(dc, text.c_str(), static_cast<int>(text.size()), &rect,
                DT_LEFT | DT_TOP | DT_WORDBREAK | DT_END_ELLIPSIS | DT_NOPREFIX);
      EndPaint(hwnd, &ps);
      return 0;
    }
    case kCaptionChanged:
      InvalidateRect(hwnd, nullptr, FALSE);
      return 0;
    case WM_LBUTTONDOWN: {
      overlay->moving = true;
      overlay->dragged = false;
      GetCursorPos(&overlay->down_screen);
      RECT rect;
      GetWindowRect(hwnd, &rect);
      overlay->down_window = {rect.left, rect.top};
      SetCapture(hwnd);
      return 0;
    }
    case WM_MOUSEMOVE: {
      if (!overlay->moving) return 0;
      POINT current;
      GetCursorPos(&current);
      const int dx = current.x - overlay->down_screen.x;
      const int dy = current.y - overlay->down_screen.y;
      if (abs(dx) + abs(dy) > 8) overlay->dragged = true;
      if (overlay->dragged) {
        SetWindowPos(hwnd, HWND_TOPMOST, overlay->down_window.x + dx,
                     overlay->down_window.y + dy, 0, 0,
                     SWP_NOSIZE | SWP_NOACTIVATE);
      }
      return 0;
    }
    case WM_LBUTTONUP:
      if (overlay->moving) {
        overlay->moving = false;
        ReleaseCapture();
        if (!overlay->dragged) {
          overlay->collapsed = !overlay->collapsed;
          SetWindowPos(hwnd, HWND_TOPMOST, 0, 0,
              overlay->collapsed ? kCollapsedWidth : kExpandedWidth,
              overlay->collapsed ? kCollapsedHeight : kExpandedHeight,
              SWP_NOMOVE | SWP_NOACTIVATE);
          InvalidateRect(hwnd, nullptr, FALSE);
        }
      }
      return 0;
    case WM_CAPTURECHANGED:
      overlay->moving = false;
      return 0;
    case WM_DESTROY:
      PostQuitMessage(0);
      return 0;
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}

void overlayThread(Overlay* overlay) {
  const HINSTANCE instance = GetModuleHandleW(nullptr);
  WNDCLASSW wc{};
  wc.lpfnWndProc = windowProc;
  wc.hInstance = instance;
  wc.hCursor = LoadCursorW(nullptr, IDC_HAND);
  wc.lpszClassName = kWindowClass;
  const ATOM registered = RegisterClassW(&wc);
  HWND hwnd = nullptr;
  if (registered || GetLastError() == ERROR_CLASS_ALREADY_EXISTS) {
    hwnd = CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
        kWindowClass, L"In4Up", WS_POPUP, 40, 140, kExpandedWidth, kExpandedHeight,
        nullptr, nullptr, instance, overlay);
  }
  {
    std::lock_guard<std::mutex> lock(overlay->mutex);
    overlay->thread_id = GetCurrentThreadId();
    overlay->window = hwnd;
    overlay->initialized = true;
    overlay->ready.notify_one();
  }
  if (!hwnd) return;
  ShowWindow(hwnd, SW_SHOWNOACTIVATE);
  UpdateWindow(hwnd);
  MSG message;
  while (GetMessageW(&message, nullptr, 0, 0) > 0) {
    TranslateMessage(&message);
    DispatchMessageW(&message);
  }
  if (IsWindow(hwnd)) DestroyWindow(hwnd);
  std::lock_guard<std::mutex> lock(overlay->mutex);
  overlay->window = nullptr;
}
}  // namespace

// Synchronous construction; all window calls thereafter happen on its own UI
// thread. The caller must destroy the handle before unloading the DLL.
CABIN_EXPORT void* cabin_overlay_create() {
  auto* overlay = new (std::nothrow) Overlay();
  if (!overlay) return nullptr;
  try {
    overlay->thread = std::thread(overlayThread, overlay);
  } catch (...) {
    delete overlay;
    return nullptr;
  }
  std::unique_lock<std::mutex> lock(overlay->mutex);
  overlay->ready.wait(lock, [overlay] { return overlay->initialized; });
  if (overlay->window) return overlay;
  lock.unlock();
  overlay->thread.join();
  delete overlay;
  return nullptr;
}

// Text is copied while holding the mutex; no user text is persisted or logged.
CABIN_EXPORT int cabin_overlay_set_text(void* handle, const wchar_t* text) {
  auto* overlay = static_cast<Overlay*>(handle);
  if (!overlay || !text) return -1;
  std::lock_guard<std::mutex> lock(overlay->mutex);
  if (!overlay->window) return -1;
  try {
    overlay->caption.assign(text, wcsnlen_s(text, 4096));
  } catch (...) { return -1; }
  return PostMessageW(overlay->window, kCaptionChanged, 0, 0) ? 0 : -1;
}

CABIN_EXPORT void cabin_overlay_destroy(void* handle) {
  auto* overlay = static_cast<Overlay*>(handle);
  if (!overlay) return;
  {
    std::lock_guard<std::mutex> lock(overlay->mutex);
    if (overlay->window && !PostMessageW(overlay->window, WM_CLOSE, 0, 0)) {
      PostThreadMessageW(overlay->thread_id, WM_QUIT, 0, 0);
    }
  }
  if (overlay->thread.joinable()) overlay->thread.join();
  delete overlay;
}
