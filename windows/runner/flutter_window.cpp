#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // The app draws its own title bar: move/resize/minimise/maximise/close come
  // from Flutter, and WM_NCCALCSIZE below removes the system caption.
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "open_chess/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        HWND hwnd = GetHandle();
        const std::string& method = call.method_name();
        if (method == "startDrag" || method == "startResize") {
          // GdkWindowEdge order (NW, N, NE, W, E, SW, S, SE) -> hit-test codes.
          static const WPARAM kEdges[] = {HTTOPLEFT,    HTTOP,    HTTOPRIGHT,
                                          HTLEFT,       HTRIGHT,  HTBOTTOMLEFT,
                                          HTBOTTOM,     HTBOTTOMRIGHT};
          WPARAM hit = HTCAPTION;
          if (method == "startResize") {
            const auto* edge = std::get_if<int32_t>(call.arguments());
            if (edge == nullptr || *edge < 0 || *edge > 7) {
              result->Error("bad-edge");
              return;
            }
            hit = kEdges[*edge];
          }
          result->Success();
          POINT pt;
          GetCursorPos(&pt);
          ReleaseCapture();
          SendMessage(hwnd, WM_NCLBUTTONDOWN, hit, MAKELPARAM(pt.x, pt.y));
          return;
        }
        if (method == "minimize") {
          ShowWindow(hwnd, SW_MINIMIZE);
        } else if (method == "toggleMaximize") {
          ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
        } else if (method == "close") {
          // Same request as the system close button.
          PostMessage(hwnd, WM_CLOSE, 0, 0);
        } else {
          result->NotImplemented();
          return;
        }
        result->Success();
      });

  // Re-run WM_NCCALCSIZE now that it removes the caption.
  SetWindowPos(GetHandle(), nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_NCCALCSIZE:
      // No system caption or frame: the whole window is client area. A
      // maximised window would overhang the screen by its frame, so it is
      // clamped to the monitor's work area (keeps the taskbar visible).
      if (wparam == TRUE) {
        if (IsZoomed(hwnd)) {
          auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
          MONITORINFO info{sizeof(info)};
          if (GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                             &info)) {
            params->rgrc[0] = info.rcWork;
          }
        }
        return 0;
      }
      break;
    case WM_SIZE:
      if (window_channel_ && wparam != SIZE_MINIMIZED) {
        bool maximized = wparam == SIZE_MAXIMIZED;
        window_channel_->InvokeMethod(
            "state", std::make_unique<flutter::EncodableValue>(
                         flutter::EncodableMap{
                             {flutter::EncodableValue("maximized"),
                              flutter::EncodableValue(maximized)},
                             {flutter::EncodableValue("framed"),
                              flutter::EncodableValue(!maximized)},
                         }));
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
