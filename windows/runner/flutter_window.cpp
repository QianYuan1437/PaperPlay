#include "flutter_window.h"

#include <optional>
#include <psapi.h>
#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "shell_identity.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }
  paperplay::SetWindowIdentity(GetHandle());

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  metrics_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "paperplay/metrics",
      &flutter::StandardMethodCodec::GetInstance());
  metrics_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "resetBackdrop") {
      // flutter_acrylic 1.1.4 does not clear the modern Windows 11 backdrop
      // when returning to solid/transparent. Reset it before applying the next
      // material so an old acrylic surface cannot remain underneath.
      const int none = 1;  // DWMSBT_NONE; SDK-independent for Windows 10 builds.
      DwmSetWindowAttribute(GetHandle(), 38, &none, sizeof(none));
      result->Success();
      return;
    }
    if (call.method_name() == "effects") {
      const auto supports_build = [](DWORD build) {
        OSVERSIONINFOEXW version{};
        version.dwOSVersionInfoSize = sizeof(version);
        version.dwMajorVersion = 10;
        version.dwBuildNumber = build;
        DWORDLONG mask = VerSetConditionMask(0, VER_MAJORVERSION, VER_GREATER_EQUAL);
        mask = VerSetConditionMask(mask, VER_BUILDNUMBER, VER_GREATER_EQUAL);
        return VerifyVersionInfoW(&version, VER_MAJORVERSION | VER_BUILDNUMBER, mask) != FALSE;
      };
      using V = flutter::EncodableValue;
      int backdrop = 0;
      const bool queried = SUCCEEDED(DwmGetWindowAttribute(GetHandle(), 38, &backdrop, sizeof(backdrop)));
      result->Success(V(flutter::EncodableMap{
        {V("acrylic"), V(supports_build(17134))},
        {V("mica"), V(supports_build(22000))},
        {V("backdropType"), queried ? V(backdrop) : V()},
      }));
      return;
    }
    if (call.method_name() != "sample") {
      result->NotImplemented();
      return;
    }
    FILETIME created{}, exited{}, kernel{}, user{};
    PROCESS_MEMORY_COUNTERS_EX memory{};
    memory.cb = sizeof(memory);
    IO_COUNTERS io{};
    const auto process = GetCurrentProcess();
    if (!GetProcessTimes(process, &created, &exited, &kernel, &user) ||
        !GetProcessMemoryInfo(process, reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&memory), sizeof(memory)) ||
        !GetProcessIoCounters(process, &io)) {
      result->Error("metrics_unavailable", "Windows process counters are unavailable");
      return;
    }
    const auto ticks = [](FILETIME time) -> int64_t {
      return (static_cast<int64_t>(time.dwHighDateTime) << 32) | time.dwLowDateTime;
    };
    LARGE_INTEGER clock{}, frequency{};
    QueryPerformanceCounter(&clock);
    QueryPerformanceFrequency(&frequency);
    using V = flutter::EncodableValue;
    result->Success(V(flutter::EncodableMap{
      {V("cpuTicks"), V(ticks(kernel) + ticks(user))},
      {V("seconds"), V(static_cast<double>(clock.QuadPart) / frequency.QuadPart)},
      {V("processors"), V(static_cast<int32_t>(GetActiveProcessorCount(ALL_PROCESSOR_GROUPS)))},
      {V("workingSet"), V(static_cast<int64_t>(memory.WorkingSetSize))},
      {V("privateBytes"), V(static_cast<int64_t>(memory.PrivateUsage))},
      {V("ioBytes"), V(static_cast<int64_t>(io.ReadTransferCount + io.WriteTransferCount))},
    }));
  });

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
  metrics_channel_.reset();
  paperplay::ClearWindowIdentity(GetHandle());
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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
