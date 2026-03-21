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
$ArtifactPath = Join-Path $DistDir "$ArtifactName.msix"
$BundleDir = Join-Path $RepoRoot "build\windows\x64\runner\Release"

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
Get-ChildItem -Force $DistDir | Where-Object { $_.Name -ne ".gitkeep" } | Remove-Item -Recurse -Force

& $FlutterBin build windows --release

$ExePath = Join-Path $BundleDir "Spinamp.exe"
if (-not (Test-Path $ExePath)) {
    throw "Expected Windows executable was not produced at $ExePath"
}

& dart run msix:create --output-path $DistDir --output-name $ArtifactName --build-windows false --install-certificate false

if (-not (Test-Path $ArtifactPath)) {
    throw "Expected Windows installer was not produced at $ArtifactPath"
}

Write-Output $ArtifactPath
