#define MyAppName "ktop"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "t3m3d"
#define MyAppURL "https://github.com/t3m3d/klennie"
#define MyAppExeName "ktop.exe"

[Setup]
AppId={{8F3A1B2C-4D5E-6F7A-8B9C-0D1E2F3A4B5C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\ktop
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=installer
OutputBaseFilename=ktop-setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ChangesEnvironment=yes
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "ktop.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\ktop"; Filename: "{app}\{#MyAppExeName}"

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueType: expandsz; ValueName: "Path"; \
    ValueData: "{olddata};{app}"; \
    Check: NeedsAddPath('{app}')

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath) then begin
    Result := True;
    exit;
  end;
  Result := Pos(';' + Param + ';', ';' + OrigPath + ';') = 0;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  OrigPath: string;
  AppPath: string;
  NewPath: string;
  P: Integer;
begin
  if CurUninstallStep = usPostUninstall then begin
    AppPath := ExpandConstant('{app}');
    if RegQueryStringValue(HKEY_LOCAL_MACHINE,
      'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
      'Path', OrigPath) then begin
      P := Pos(';' + AppPath, OrigPath);
      if P > 0 then begin
        NewPath := Copy(OrigPath, 1, P - 1) + Copy(OrigPath, P + Length(';' + AppPath), MaxInt);
        RegWriteStringValue(HKEY_LOCAL_MACHINE,
          'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
          'Path', NewPath);
      end;
    end;
  end;
end;
