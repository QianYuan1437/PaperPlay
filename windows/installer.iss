#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif
[Setup]
AppId={{3082DC15-5A94-49FC-8C3A-B69D7A71A8B1}
AppName=PaperPlay
AppVersion={#AppVersion}
AppPublisher=QianYuan1437
AppPublisherURL=https://github.com/QianYuan1437/PaperPlay
DefaultDirName={localappdata}\Programs\PaperPlay
DefaultGroupName=PaperPlay
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=PaperPlay-{#AppVersion}-windows-x64-setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\paperplay.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
LicenseFile=..\LICENSE
CloseApplications=yes
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\PaperPlay"; Filename: "{app}\paperplay.exe"
Name: "{autodesktop}\PaperPlay"; Filename: "{app}\paperplay.exe"; Tasks: desktopicon
[Run]
Filename: "{app}\paperplay.exe"; Description: "Launch PaperPlay"; Flags: nowait postinstall skipifsilent
