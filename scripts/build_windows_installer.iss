; Inno Setup Script for ImageMixer

#define AppName "ImageMixer"
#define AppVersion "1.0.0"
#define AppPublisher "ImageMixer"
#define AppBuildDir "frontend\\build\\windows\\x64\\runner\\Release"
#define AppExeName "imagemixer_desktop.exe"

[Setup]
AppId={{A0A1C54B-8F62-4F3D-9F8C-6C88A9B2F11D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir=dist
OutputBaseFilename=ImageMixer-Setup
Compression=lzma
SolidCompression=yes
DisableProgramGroupPage=yes

[Files]
Source: "{#AppBuildDir}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
