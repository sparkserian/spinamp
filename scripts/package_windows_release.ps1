param(
    [string]$FlutterBin = "flutter"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$PubspecPath = Join-Path $RepoRoot "pubspec.yaml"
$PubspecContent = Get-Content $PubspecPath
$VersionLine = ($PubspecContent | Select-String -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()

if ([string]::IsNullOrWhiteSpace($VersionLine)) {
    throw "Unable to determine version from pubspec.yaml"
}

$ArtifactVersion = "v$VersionLine"
$DistDir = Join-Path $RepoRoot "dist"
$ArtifactName = "spinamp-windows-installer-$ArtifactVersion"
$ArtifactPath = Join-Path $DistDir "$ArtifactName.exe"
$BundleDir = Join-Path $RepoRoot "build\windows\x64\runner\Release"
$InnoScriptPath = Join-Path $RepoRoot "build\windows-installer.iss"

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
Get-ChildItem -Force $DistDir | Where-Object { $_.Name -ne ".gitkeep" } | Remove-Item -Recurse -Force

& $FlutterBin build windows --release

$ExePath = Join-Path $BundleDir "Spinamp.exe"
if (-not (Test-Path $ExePath)) {
    throw "Expected Windows executable was not produced at $ExePath"
}

$IsccCandidates = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)
$IsccPath = $IsccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($IsccPath)) {
    throw "Inno Setup compiler not found. Install Inno Setup 6 or set up the GitHub runner accordingly."
}

$SetupScript = @"
#define MyAppName "Spinamp"
#define MyAppVersion "$VersionLine"
#define MyAppPublisher "Spinamp"
#define MyAppExeName "Spinamp.exe"

[Setup]
AppId={{5D6BCA4D-2FA3-4E35-8A37-81DB82B0D15A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Spinamp
DefaultGroupName={#MyAppName}
OutputDir=$DistDir
OutputBaseFilename=$ArtifactName
SetupIconFile=$RepoRoot\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "$BundleDir\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Spinamp"; Filename: "{app}\Spinamp.exe"
Name: "{autodesktop}\Spinamp"; Filename: "{app}\Spinamp.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Spinamp.exe"; Description: "{cm:LaunchProgram,Spinamp}"; Flags: nowait postinstall skipifsilent
"@

Set-Content -Path $InnoScriptPath -Value $SetupScript -Encoding ASCII

& $IsccPath $InnoScriptPath

if (-not (Test-Path $ArtifactPath)) {
    throw "Expected Windows installer was not produced at $ArtifactPath"
}

Write-Output $ArtifactPath
