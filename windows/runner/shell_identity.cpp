#include "shell_identity.h"
#include <propkey.h>
#include <propvarutil.h>
#include <shobjidl.h>
#include <wrl/client.h>
#include <vector>
#include "resource.h"

namespace paperplay {
std::wstring ExecutablePath() {
  std::vector<wchar_t> buffer(32768);
  const DWORD length = ::GetModuleFileNameW(nullptr, buffer.data(),
                                          static_cast<DWORD>(buffer.size()));
  if (length == 0 || length >= buffer.size()) return {};
  return std::wstring(buffer.data(), length);
}

HRESULT SetProcessIdentity() {
  return ::SetCurrentProcessExplicitAppUserModelID(kAppUserModelId);
}

HRESULT SetWindowIdentity(HWND window) {
  const auto executable = ExecutablePath();
  if (executable.empty()) return E_FAIL;
  Microsoft::WRL::ComPtr<IPropertyStore> properties;
  HRESULT result = ::SHGetPropertyStoreForWindow(window, IID_PPV_ARGS(&properties));
  if (FAILED(result)) return result;
  const auto set = [&](REFPROPERTYKEY key, const std::wstring& value) {
    PROPVARIANT variant;
    HRESULT status = ::InitPropVariantFromString(value.c_str(), &variant);
    if (SUCCEEDED(status)) {
      status = properties->SetValue(key, variant);
      ::PropVariantClear(&variant);
    }
    return status;
  };
  // Pinning must resolve to the installed executable, never to a transient
  // playback icon or a command inherited from a launcher/installer.
  result = set(PKEY_AppUserModel_RelaunchCommand, L"\"" + executable + L"\"");
  if (FAILED(result)) return result;
  result = set(PKEY_AppUserModel_RelaunchIconResource, executable + L",0");
  if (FAILED(result)) return result;
  result = set(PKEY_AppUserModel_RelaunchDisplayNameResource,
               L"@" + executable + L",-" + std::to_wstring(IDS_APP_TITLE));
  if (FAILED(result)) return result;
  result = set(PKEY_AppUserModel_ID, kAppUserModelId);
  return FAILED(result) ? result : properties->Commit();
}

void ClearWindowIdentity(HWND window) {
  if (!window) return;
  Microsoft::WRL::ComPtr<IPropertyStore> properties;
  if (FAILED(::SHGetPropertyStoreForWindow(window, IID_PPV_ARGS(&properties)))) return;
  const PROPVARIANT empty{};
  for (const auto& key : {PKEY_AppUserModel_ID, PKEY_AppUserModel_RelaunchCommand,
                         PKEY_AppUserModel_RelaunchIconResource,
                         PKEY_AppUserModel_RelaunchDisplayNameResource}) {
    properties->SetValue(key, empty);
  }
}
}  // namespace paperplay
