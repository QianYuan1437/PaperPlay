#ifndef RUNNER_SHELL_IDENTITY_H_
#define RUNNER_SHELL_IDENTITY_H_
#include <windows.h>
#include <string>

namespace paperplay {
// Shared with installer.iss. Never include a version or installation path.
inline constexpr wchar_t kAppUserModelId[] = L"QianYuan1437.PaperPlay";
std::wstring ExecutablePath();
HRESULT SetProcessIdentity();
HRESULT SetWindowIdentity(HWND window);
void ClearWindowIdentity(HWND window);
}  // namespace paperplay
#endif
