; rodon.iss — інсталятор RodON для Windows (Inno Setup 6)
; Викликається з windows_build.ps1:
;   ISCC.exe /DStageDir=... /DOutDir=... rodon.iss

#ifndef StageDir
  #define StageDir "..\build\windows-stage"
#endif
#ifndef OutDir
  #define OutDir ".."
#endif

#define AppName "RodON"
#define AppExe  "RodON.exe"
; Версія береться з самого RodON.exe
#define AppVersion GetVersionNumbersString(AddBackslash(StageDir) + AppExe)

[Setup]
; НЕ змінюй AppId між версіями — за ним Windows знаходить попередню установку
AppId={{6F3B2A41-8C1D-4E6B-9A7F-2D5C0E9B1A44}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=RodON
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir={#OutDir}
; Version in the file name - needed for the updates server
OutputBaseFilename=RodON-Setup-{#AppVersion}
SetupIconFile=rodon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Встановлення в Program Files потребує прав адміністратора
PrivilegesRequired=admin
CloseApplications=yes

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "uk"; MessagesFile: "compiler:Languages\Ukrainian.isl"
Name: "de"; MessagesFile: "compiler:Languages\German.isl"
Name: "pl"; MessagesFile: "compiler:Languages\Polish.isl"
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"
Name: "it"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; Excludes: "vc_redist*.exe"; Flags: ignoreversion recursesubdirs createallsubdirs
; Visual C++ runtime (windeployqt --compiler-runtime кладе інсталятор у staging)
Source: "{#StageDir}\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall skipifsourcedoesntexist

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; \
  StatusMsg: "Installing Visual C++ runtime..."; Flags: waituntilterminated skipifdoesntexist
; Служба VPN (SYSTEM). Без неї RodON.exe не може підняти тунель
Filename: "{app}\RodONService.exe"; Parameters: "--install"; \
  StatusMsg: "Installing RodON VPN service..."; Flags: runhidden waituntilterminated
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
; After a silent update (WinSparkle runs setup with /SILENT) restart the app as the normal user
Filename: "{app}\{#AppExe}"; Flags: nowait runasoriginaluser; Check: WizardSilent

[UninstallRun]
Filename: "{app}\RodONService.exe"; Parameters: "--uninstall"; RunOnceId: "RemoveRodONService"; Flags: runhidden waituntilterminated

[Code]
// Перед оновленням зупиняємо службу і тунель, інакше RodONService.exe,
// tunnel.dll і wireguard.dll зайняті й не перезапишуться
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Svc: String;
  Code: Integer;
begin
  Result := '';
  Svc := ExpandConstant('{app}\RodONService.exe');
  if FileExists(Svc) then
    Exec(Svc, '--stop', '', SW_HIDE, ewWaitUntilTerminated, Code);
end;
