; Slate installer (Inno Setup 6).
; Build:  iscc /DAppVersion=1.0.0 /DSourceDir=..\..\dist /DOutputDir=..\..\installer packaging\windows\slate.iss
;
; What it does on Windows:
;  - installs Slate to Program Files (all users) or %LOCALAPPDATA%\Programs (just me)
;  - Start menu shortcut, optional desktop shortcut, uninstaller in Apps & features
;  - registers Slate for video and audio files (ProgIDs + "Open with"), and as a
;    registered application so it shows up in Settings > Apps > Default apps
;  - adds "Review folder in Slate" to the folder right-click menu (optional)
;  - offers to open Default apps at the end so Slate can be made the default player

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\dist"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\installer"
#endif

#define AppName "Slate"
#define AppExe  "Slate.exe"
#define CapKey  "Software\Slate\Capabilities"

[Setup]
AppId={{6C1E5B1F-3F7A-4C1B-9B8E-2D9A1F5E7C42}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Ryan Mendes
VersionInfoVersion={#AppVersion}
VersionInfoDescription=Slate media player installer
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=Slate-Setup
SetupIconFile=slate.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
ChangesAssociations=yes
CloseApplications=yes
RestartApplications=no
ShowLanguageDialog=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked
Name: "folderverb"; Description: "Add ""Review folder in Slate"" to the folder right-click menu"; GroupDescription: "Explorer:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "Slate.Player"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
; ---- application identity ---------------------------------------------------------
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\DefaultIcon"; ValueType: string; ValueData: """{app}\{#AppExe}"",0"
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExe}"" ""%1"""
Root: HKA; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\{#AppExe}"; ValueType: string; ValueData: "{app}\{#AppExe}"; Flags: uninsdeletekey

; ---- ProgIDs ----------------------------------------------------------------------
Root: HKA; Subkey: "Software\Classes\Slate.Video"; ValueType: string; ValueData: "Video (Slate)"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Slate.Video"; ValueType: string; ValueName: "FriendlyTypeName"; ValueData: "Video"
Root: HKA; Subkey: "Software\Classes\Slate.Video\DefaultIcon"; ValueType: string; ValueData: """{app}\{#AppExe}"",0"
Root: HKA; Subkey: "Software\Classes\Slate.Video\shell"; ValueType: string; ValueData: "open"
Root: HKA; Subkey: "Software\Classes\Slate.Video\shell\open"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"
Root: HKA; Subkey: "Software\Classes\Slate.Video\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExe}"" ""%1"""

Root: HKA; Subkey: "Software\Classes\Slate.Audio"; ValueType: string; ValueData: "Audio (Slate)"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Slate.Audio"; ValueType: string; ValueName: "FriendlyTypeName"; ValueData: "Audio"
Root: HKA; Subkey: "Software\Classes\Slate.Audio\DefaultIcon"; ValueType: string; ValueData: """{app}\{#AppExe}"",0"
Root: HKA; Subkey: "Software\Classes\Slate.Audio\shell"; ValueType: string; ValueData: "open"
Root: HKA; Subkey: "Software\Classes\Slate.Audio\shell\open"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"
Root: HKA; Subkey: "Software\Classes\Slate.Audio\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExe}"" ""%1"""

; ---- registered application (Settings > Default apps) ------------------------------
Root: HKA; Subkey: "{#CapKey}"; Flags: uninsdeletekey
Root: HKA; Subkey: "{#CapKey}"; ValueType: string; ValueName: "ApplicationName"; ValueData: "{#AppName}"
Root: HKA; Subkey: "{#CapKey}"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "Fast media player for reviewing clips: frame stepping, markers, waveforms and exports."
Root: HKA; Subkey: "{#CapKey}"; ValueType: string; ValueName: "ApplicationIcon"; ValueData: """{app}\{#AppExe}"",0"
Root: HKA; Subkey: "Software\RegisteredApplications"; ValueType: string; ValueName: "{#AppName}"; ValueData: "{#CapKey}"; Flags: uninsdeletevalue

; ---- folder right-click: Review folder in Slate --------------------------------------
Root: HKA; Subkey: "Software\Classes\Directory\shell\Slate"; ValueType: string; ValueData: "Review folder in Slate"; Tasks: folderverb; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Directory\shell\Slate"; ValueType: string; ValueName: "Icon"; ValueData: """{app}\{#AppExe}"",0"; Tasks: folderverb
Root: HKA; Subkey: "Software\Classes\Directory\shell\Slate\command"; ValueType: string; ValueData: """{app}\{#AppExe}"" ""%1"""; Tasks: folderverb

[Run]
; after a silent update started from inside Slate (/RELAUNCH), reopen it
Filename: "{app}\{#AppExe}"; Flags: nowait; Check: ShouldRelaunch
Filename: "{app}\{#AppExe}"; Description: "Open Slate now"; Flags: nowait postinstall skipifsilent unchecked
Filename: "{code:DefaultAppsUri}"; Description: "Make Slate my default video player (opens Windows Settings)"; Flags: shellexec nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
const
  VideoExts = '.mp4 .m4v .mov .mkv .webm .avi .wmv .flv .mpg .mpeg .m2ts .mts .ts .3gp .ogv .mxf';
  AudioExts = '.mp3 .wav .flac .m4a .aac .ogg .opus .wma .aif .aiff';

function ShouldRelaunch(): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), '/RELAUNCH') = 0 then Result := True;
end;

function RootKey(): Integer;
begin
  if IsAdminInstallMode then Result := HKEY_LOCAL_MACHINE else Result := HKEY_CURRENT_USER;
end;

function DefaultAppsUri(Param: String): String;
begin
  if IsAdminInstallMode then
    Result := 'ms-settings:defaultapps?registeredAppMachine={#AppName}'
  else
    Result := 'ms-settings:defaultapps?registeredAppUser={#AppName}';
end;

procedure RegisterExts(Exts, ProgId, Perceived: String);
var
  Rest, Ext: String;
  P: Integer;
begin
  Rest := Exts + ' ';
  while Length(Rest) > 0 do
  begin
    P := Pos(' ', Rest);
    Ext := Copy(Rest, 1, P - 1);
    Delete(Rest, 1, P);
    if Ext = '' then Continue;
    { "Open with" list and the Default apps capability }
    RegWriteStringValue(RootKey(), 'Software\Classes\' + Ext + '\OpenWithProgids', ProgId, '');
    RegWriteStringValue(RootKey(), 'Software\Classes\Applications\{#AppExe}\SupportedTypes', Ext, '');
    RegWriteStringValue(RootKey(), '{#CapKey}\FileAssociations', Ext, ProgId);
    if not RegValueExists(RootKey(), 'Software\Classes\' + Ext, 'PerceivedType') then
      RegWriteStringValue(RootKey(), 'Software\Classes\' + Ext, 'PerceivedType', Perceived);
  end;
end;

procedure UnregisterExts(Exts, ProgId: String);
var
  Rest, Ext: String;
  P: Integer;
begin
  Rest := Exts + ' ';
  while Length(Rest) > 0 do
  begin
    P := Pos(' ', Rest);
    Ext := Copy(Rest, 1, P - 1);
    Delete(Rest, 1, P);
    if Ext = '' then Continue;
    RegDeleteValue(RootKey(), 'Software\Classes\' + Ext + '\OpenWithProgids', ProgId);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    RegisterExts(VideoExts, 'Slate.Video', 'video');
    RegisterExts(AudioExts, 'Slate.Audio', 'audio');
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    UnregisterExts(VideoExts, 'Slate.Video');
    UnregisterExts(AudioExts, 'Slate.Audio');
  end;
end;
