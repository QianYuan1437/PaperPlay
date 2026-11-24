#include <windows.h>
#include <shobjidl.h>
#include <propkey.h>
#include <propvarutil.h>
#include <shlwapi.h>
#include <wrl/client.h>
#include <filesystem>
#include <iostream>
#include <stdexcept>
#include "shell_identity.h"
#include "resource.h"

void Check(bool value, const char* message) {
  if (!value) throw std::runtime_error(message);
}
std::wstring Read(IPropertyStore* store, REFPROPERTYKEY key) {
  PROPVARIANT value{};
  Check(SUCCEEDED(store->GetValue(key, &value)), "Read window property");
  const std::wstring result = value.vt == VT_LPWSTR ? value.pwszVal : L"";
  ::PropVariantClear(&value);
  return result;
}
int main() {
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  try {
    const auto executable = paperplay::ExecutablePath();
    Check(std::filesystem::exists(executable), "Executable path must exist");
    wchar_t temporary[MAX_PATH];
    ::GetTempPathW(MAX_PATH, temporary);
    ::SetCurrentDirectoryW(temporary);
    Check(paperplay::ExecutablePath() == executable, "Identity must ignore working directory");
    Check(SUCCEEDED(paperplay::SetProcessIdentity()), "Set process identity");
    PWSTR id = nullptr;
    Check(SUCCEEDED(::GetCurrentProcessExplicitAppUserModelID(&id)), "Read process identity");
    Check(std::wstring(id) == paperplay::kAppUserModelId, "Process identity mismatch");
    ::CoTaskMemFree(id);
    HWND window = ::CreateWindowExW(0, L"STATIC", L"Shell test", WS_OVERLAPPED,
        0, 0, 1, 1, nullptr, nullptr, ::GetModuleHandleW(nullptr), nullptr);
    Check(window != nullptr, "Create hidden test window");
    {
      Microsoft::WRL::ComPtr<IPropertyStore> store;
      Check(SUCCEEDED(::SHGetPropertyStoreForWindow(window, IID_PPV_ARGS(&store))), "Get window store");
      Check(Read(store.Get(), PKEY_AppUserModel_ID).empty(), "Baseline window has no explicit identity");
      Check(SUCCEEDED(paperplay::SetWindowIdentity(window)), "Configure window identity");
      Check(Read(store.Get(), PKEY_AppUserModel_ID) == paperplay::kAppUserModelId, "Window identity mismatch");
      Check(Read(store.Get(), PKEY_AppUserModel_RelaunchCommand) == L"\"" + executable + L"\"", "Relaunch command must quote the real executable");
      Check(Read(store.Get(), PKEY_AppUserModel_RelaunchIconResource) == executable + L",0", "Pinned icon must use embedded executable resource");
      Check(Read(store.Get(), PKEY_AppUserModel_RelaunchDisplayNameResource) == L"@" + executable + L",-102", "Display name resource mismatch");
      Check(SUCCEEDED(paperplay::SetWindowIdentity(window)), "Repeated registration must be idempotent");
      paperplay::ClearWindowIdentity(window);
      Check(Read(store.Get(), PKEY_AppUserModel_ID).empty(), "Properties must be released before closing the window");
    }
    wchar_t title[64];
    Check(::LoadStringW(::GetModuleHandleW(nullptr), IDS_APP_TITLE, title, 64) > 0 && std::wstring(title) == L"PaperPlay", "Embedded display name must resolve");
    HICON largeIcon = nullptr, smallIcon = nullptr;
    const auto extracted = ::ExtractIconExW(executable.c_str(), 0, &largeIcon, &smallIcon, 1);
    std::cout << "Extracted icons: " << extracted << " large=" << largeIcon << " small=" << smallIcon << "\n";
    Check(extracted > 0 && largeIcon && smallIcon, "Embedded pinned icon must resolve");
    ::DestroyIcon(largeIcon); ::DestroyIcon(smallIcon); ::DestroyWindow(window);
    std::cout << "PASS: stable process/window identity, quoted relaunch path, embedded icon/name, arbitrary working directory\n";
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    ::CoUninitialize();
    return 1;
  }
  ::CoUninitialize();
  return 0;
}
