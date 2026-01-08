; DRL Simulator Community - Windows Installer
; Inno Setup Script
; Compile with Inno Setup 6.x: https://jrsoftware.org/isinfo.php

#define MyAppName "DRL Simulator Community"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "DRL Community"
#define MyAppURL "https://github.com/Georgeandrew7/DRL-Simulator-Community"
#define MyAppExeName "start-offline-mode.bat"

[Setup]
; Basic installer info
AppId={{8F4E9B2C-3D1A-4E5F-B6C7-8D9E0F1A2B3C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\DRL-Community
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE
InfoBeforeFile=installer\README_BEFORE.txt
InfoAfterFile=installer\README_AFTER.txt
OutputDir=installer\output
OutputBaseFilename=DRL-Community-Setup-{#MyAppVersion}
; SetupIconFile=installer\icon.ico  ; Uncomment when icon.ico is added
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
; UninstallDisplayIcon={app}\icon.ico  ; Uncomment when icon.ico is added
UninstallDisplayName={#MyAppName}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=DRL Simulator Community Server and Mods
VersionInfoCopyright=MIT License
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "full"; Description: "Full installation (recommended)"
Name: "compact"; Description: "Compact installation (server only)"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
Name: "core"; Description: "Core Files (required)"; Types: full compact custom; Flags: fixed
Name: "server"; Description: "Mock Backend Server"; Types: full compact custom
Name: "bepinex"; Description: "BepInEx Mod Framework"; Types: full custom
Name: "plugins"; Description: "Community Plugins (SSL Bypass, License Bypass)"; Types: full custom
Name: "tools"; Description: "Utility Tools (Binary Patcher, Extractors)"; Types: full custom
Name: "docs"; Description: "Documentation"; Types: full custom

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "hosts"; Description: "Add api.drlgame.com to hosts file (required for offline play)"; GroupDescription: "Network Configuration:"
Name: "firewall"; Description: "Add Windows Firewall exceptions"; GroupDescription: "Network Configuration:"; Flags: unchecked
Name: "startmenu"; Description: "Create Start Menu shortcuts"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Core files
Source: "..\..\common\*"; DestDir: "{app}\common"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: core
Source: "..\..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion; Components: core
Source: "..\..\README.md"; DestDir: "{app}"; Flags: ignoreversion; Components: core
Source: "..\..\requirements.txt"; DestDir: "{app}"; Flags: ignoreversion; Components: core

; Windows platform files
Source: "*.bat"; DestDir: "{app}"; Flags: ignoreversion; Components: core
Source: "*.ps1"; DestDir: "{app}"; Flags: ignoreversion; Components: core

; Server files (already in common, but mark component)
; Plugins source
Source: "..\..\common\plugins\*.cs"; DestDir: "{app}\common\plugins"; Flags: ignoreversion; Components: plugins
Source: "..\..\common\plugins\*.bat"; DestDir: "{app}\common\plugins"; Flags: ignoreversion; Components: plugins

; Compiled plugin DLLs (built by GitHub Actions)
Source: "..\..\common\plugins\compiled\*.dll"; DestDir: "{app}\plugins"; Flags: ignoreversion skipifsourcedoesntexist; Components: plugins

; Tools
Source: "..\..\common\tools\*"; DestDir: "{app}\common\tools"; Flags: ignoreversion recursesubdirs; Components: tools

; Documentation
Source: "..\..\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: docs

; Installer resources (icon is optional - uncomment when available)
; Source: "installer\icon.ico"; DestDir: "{app}"; Flags: ignoreversion; Components: core

[Dirs]
Name: "{app}\certs"
Name: "{app}\logs"
Name: "{app}\backups"

[Icons]
; Start Menu (icons will use default Windows icon if icon.ico not present)
Name: "{group}\Start Offline Mode"; Filename: "{app}\start-offline-mode.bat"; WorkingDir: "{app}"; Tasks: startmenu
Name: "{group}\Update DRL Community"; Filename: "{app}\update.bat"; WorkingDir: "{app}"; Tasks: startmenu
Name: "{group}\Diagnostics"; Filename: "{app}\diagnose.bat"; WorkingDir: "{app}"; Tasks: startmenu
Name: "{group}\Documentation"; Filename: "{app}\docs"; Tasks: startmenu
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"; Tasks: startmenu

; Desktop
Name: "{autodesktop}\DRL Offline Mode"; Filename: "{app}\start-offline-mode.bat"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
; Post-install actions
Filename: "{cmd}"; Parameters: "/c echo 127.0.0.1 api.drlgame.com >> C:\Windows\System32\drivers\etc\hosts"; Flags: runhidden; Tasks: hosts; StatusMsg: "Configuring hosts file..."
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""DRL Community HTTP"" dir=in action=allow protocol=TCP localport=80"; Flags: runhidden; Tasks: firewall; StatusMsg: "Adding firewall rules..."
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""DRL Community HTTPS"" dir=in action=allow protocol=TCP localport=443"; Flags: runhidden; Tasks: firewall
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""DRL Community Master"" dir=in action=allow protocol=TCP localport=8080"; Flags: runhidden; Tasks: firewall
Filename: "{app}\diagnose.bat"; Description: "Run diagnostics to verify installation"; Flags: nowait postinstall skipifsilent unchecked
Filename: "{app}\docs\SELF_HOSTING_GUIDE.md"; Description: "View documentation"; Flags: nowait postinstall skipifsilent shellexec unchecked

[UninstallRun]
; Cleanup on uninstall
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""DRL Community HTTP"""; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""DRL Community HTTPS"""; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""DRL Community Master"""; Flags: runhidden

[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\certs"
Type: filesandordirs; Name: "{app}\backups"

[Registry]
Root: HKLM; Subkey: "SOFTWARE\DRL-Community"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\DRL-Community"; ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"; Flags: uninsdeletekey

[Code]
var
  GameDirPage: TInputDirWizardPage;
  PythonPage: TOutputMsgWizardPage;
  GameDir: String;
  PythonInstalled: Boolean;

// Check if Python is installed
function IsPythonInstalled: Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec('python', '--version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
  if not Result then
    Result := Exec('python3', '--version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

// Find DRL Simulator installation
function FindGameDir: String;
var
  Paths: array[0..5] of String;
  I: Integer;
begin
  Result := '';
  Paths[0] := ExpandConstant('{pf32}\Steam\steamapps\common\DRL Simulator');
  Paths[1] := ExpandConstant('{pf}\Steam\steamapps\common\DRL Simulator');
  Paths[2] := 'D:\Steam\steamapps\common\DRL Simulator';
  Paths[3] := 'D:\SteamLibrary\steamapps\common\DRL Simulator';
  Paths[4] := 'E:\Steam\steamapps\common\DRL Simulator';
  Paths[5] := 'E:\SteamLibrary\steamapps\common\DRL Simulator';
  
  for I := 0 to 5 do
  begin
    if FileExists(Paths[I] + '\DRL Simulator.exe') then
    begin
      Result := Paths[I];
      Exit;
    end;
  end;
end;

// Check if hosts entry already exists
function HostsEntryExists: Boolean;
var
  HostsContent: AnsiString;
begin
  Result := False;
  if LoadStringFromFile('C:\Windows\System32\drivers\etc\hosts', HostsContent) then
    Result := Pos('api.drlgame.com', HostsContent) > 0;
end;

procedure InitializeWizard;
begin
  // Create custom page for game directory
  GameDirPage := CreateInputDirPage(wpSelectDir,
    'Select Game Directory',
    'Where is DRL Simulator installed?',
    'Select the folder where DRL Simulator is installed, then click Next.',
    False, '');
  GameDirPage.Add('');
  
  // Try to find game automatically
  GameDir := FindGameDir;
  if GameDir <> '' then
    GameDirPage.Values[0] := GameDir
  else
    GameDirPage.Values[0] := ExpandConstant('{pf32}\Steam\steamapps\common\DRL Simulator');
  
  // Create Python status page
  PythonPage := CreateOutputMsgPage(GameDirPage.ID,
    'Python Check',
    'Checking Python installation...',
    '');
  
  PythonInstalled := IsPythonInstalled;
  if PythonInstalled then
    PythonPage.MsgLabel.Caption := 
      'Python is installed!' + #13#10 + #13#10 +
      'The mock server requires Python 3.8 or later.' + #13#10 +
      'Python was detected on your system.' + #13#10 + #13#10 +
      'Click Next to continue.'
  else
    PythonPage.MsgLabel.Caption := 
      'Python is NOT installed!' + #13#10 + #13#10 +
      'The mock server requires Python 3.8 or later.' + #13#10 +
      'Please install Python from https://python.org' + #13#10 + #13#10 +
      'You can continue the installation, but the server' + #13#10 +
      'will not work until Python is installed.' + #13#10 + #13#10 +
      'Click Next to continue anyway.';
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  
  // Validate game directory
  if CurPageID = GameDirPage.ID then
  begin
    GameDir := GameDirPage.Values[0];
    if not FileExists(GameDir + '\DRL Simulator.exe') then
    begin
      if MsgBox('DRL Simulator.exe was not found in the selected directory.' + #13#10 + #13#10 +
                'BepInEx installation may not work correctly.' + #13#10 +
                'Continue anyway?', mbConfirmation, MB_YESNO) = IDNO then
        Result := False;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  BepInExURL: String;
  BepInExZip: String;
  PowerShellCmd: String;
  BepInExDir: String;
begin
  if CurStep = ssPostInstall then
  begin
    // Save game directory to registry
    RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\DRL-Community', 'GamePath', GameDir);
    
    // Install BepInEx if selected and game was found
    if IsComponentSelected('bepinex') and FileExists(GameDir + '\DRL Simulator.exe') then
    begin
      BepInExDir := GameDir + '\BepInEx';
      
      // Check if BepInEx is already installed
      if not DirExists(BepInExDir) then
      begin
        BepInExURL := 'https://github.com/BepInEx/BepInEx/releases/download/v5.4.23.2/BepInEx_win_x64_5.4.23.2.zip';
        BepInExZip := ExpandConstant('{tmp}\BepInEx.zip');
        
        // Download BepInEx using PowerShell
        WizardForm.StatusLabel.Caption := 'Downloading BepInEx...';
        PowerShellCmd := '-ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri ''' + BepInExURL + ''' -OutFile ''' + BepInExZip + '''"';
        
        if Exec('powershell.exe', PowerShellCmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
        begin
          if FileExists(BepInExZip) then
          begin
            // Extract BepInEx to game directory
            WizardForm.StatusLabel.Caption := 'Installing BepInEx...';
            PowerShellCmd := '-ExecutionPolicy Bypass -Command "Expand-Archive -Path ''' + BepInExZip + ''' -DestinationPath ''' + GameDir + ''' -Force"';
            
            if Exec('powershell.exe', PowerShellCmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
            begin
              // Create plugins directory
              ForceDirectories(BepInExDir + '\plugins');
              
              // Copy plugins from installed app to game
              WizardForm.StatusLabel.Caption := 'Copying plugins...';
              PowerShellCmd := '-ExecutionPolicy Bypass -Command "if (Test-Path ''' + ExpandConstant('{app}\plugins\*.dll') + ''') { Copy-Item ''' + ExpandConstant('{app}\plugins\*.dll') + ''' ''' + BepInExDir + '\plugins\'' -Force }"';
              Exec('powershell.exe', PowerShellCmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
            end
            else
            begin
              MsgBox('Failed to extract BepInEx. Please run install-bepinex.bat manually.', mbError, MB_OK);
            end;
            
            // Clean up
            DeleteFile(BepInExZip);
          end
          else
          begin
            MsgBox('Failed to download BepInEx. Please run install-bepinex.bat manually.', mbError, MB_OK);
          end;
        end
        else
        begin
          MsgBox('PowerShell failed. Please run install-bepinex.bat manually.', mbError, MB_OK);
        end;
      end
      else
      begin
        // BepInEx already installed, just copy plugins
        WizardForm.StatusLabel.Caption := 'BepInEx already installed, copying plugins...';
        ForceDirectories(BepInExDir + '\plugins');
        PowerShellCmd := '-ExecutionPolicy Bypass -Command "if (Test-Path ''' + ExpandConstant('{app}\plugins\*.dll') + ''') { Copy-Item ''' + ExpandConstant('{app}\plugins\*.dll') + ''' ''' + BepInExDir + '\plugins\'' -Force }"';
        Exec('powershell.exe', PowerShellCmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      end;
    end;
    
    // Install Python packages if Python is installed
    if PythonInstalled then
    begin
      WizardForm.StatusLabel.Caption := 'Installing Python packages...';
      Exec('python', '-m pip install aiohttp requests cryptography --quiet', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;
    
    WizardForm.StatusLabel.Caption := 'Installation complete!';
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  
  // Check if hosts entry already exists
  if WizardIsTaskSelected('hosts') and HostsEntryExists then
  begin
    // Skip hosts modification if already present
    WizardSelectTasks('!hosts');
  end;
end;

// Uninstall: Remove hosts entry
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  HostsFile: String;
  HostsContent: AnsiString;
  NewContent: String;
  Lines: TArrayOfString;
  I: Integer;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    HostsFile := 'C:\Windows\System32\drivers\etc\hosts';
    
    // Remove hosts entry (simplified - just notify user)
    if HostsEntryExists then
    begin
      MsgBox('Note: The hosts file entry for api.drlgame.com was not automatically removed.' + #13#10 +
             'You may want to manually remove it from:' + #13#10 +
             HostsFile, mbInformation, MB_OK);
    end;
  end;
end;
