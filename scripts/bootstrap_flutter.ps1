# One-time setup: download Flutter SDK (if missing), add android/ios/web folders, run pub get.
#
# Needs ~6+ GB free on the drive where you extract the SDK (C: is used by default).
#
#   cd "path\to\APP COUCH"
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\scripts\bootstrap_flutter.ps1
# Optional: extract elsewhere if C: is full:
#   .\scripts\bootstrap_flutter.ps1 -SdkRoot "D:\flutter_sdk_stable"

param(
  [string] $SdkRoot = $(Join-Path $env:SystemDrive "flutter_sdk_stable")
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$cacheZip = Join-Path $projectRoot ".flutter_cache\flutter_windows_stable.zip"
$tempZip = Join-Path $env:TEMP "flutter_windows_stable.zip"
$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.41.6-stable.zip"

function Test-DiskSpace([string]$Path, [long]$NeededGb = 6) {
  if ($Path -notmatch '^([A-Za-z]):') { return $true }
  $letter = $Matches[1]
  $drive = Get-PSDrive -Name $letter -PSProvider FileSystem -ErrorAction SilentlyContinue
  if (-not $drive) { return $true }
  $freeGb = [math]::Round($drive.Free / 1GB, 1)
  if ($drive.Free -lt ($NeededGb * 1GB)) {
    Write-Warning "Only $freeGb GB free on ${letter}: - need about $NeededGb GB to extract Flutter. Free space or use -SdkRoot on another drive."
    return $false
  }
  return $true
}

function Find-FlutterBat {
  if (Get-Command flutter -ErrorAction SilentlyContinue) {
    return (Get-Command flutter).Source
  }
  $candidates = @(
    (Join-Path $SdkRoot "flutter\bin\flutter.bat"),
    (Join-Path $env:LOCALAPPDATA "flutter\bin\flutter.bat"),
    (Join-Path $env:USERPROFILE "flutter\bin\flutter.bat"),
    "C:\src\flutter\bin\flutter.bat"
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { return $c }
  }
  return $null
}

$flutterBat = Find-FlutterBat

if (-not $flutterBat) {
  if (-not (Test-DiskSpace $SdkRoot)) {
    exit 1
  }

  $zip = if (Test-Path $cacheZip) {
    Write-Host "Using existing zip: $cacheZip"
    $cacheZip
  } else {
    Write-Host "Downloading Flutter SDK zip to $tempZip ..."
    if (Test-Path $tempZip) { Remove-Item -Force $tempZip }
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
      & curl.exe -L --retry 3 --retry-delay 5 -o $tempZip $url
    } else {
      Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing
    }
    $tempZip
  }

  if (Test-Path (Join-Path $SdkRoot "flutter")) {
    Write-Host "Removing old $SdkRoot\flutter ..."
    Remove-Item -Recurse -Force (Join-Path $SdkRoot "flutter")
  }
  New-Item -ItemType Directory -Path $SdkRoot -Force | Out-Null

  Write-Host "Extracting to $SdkRoot (tar is more reliable than Expand-Archive for this zip)..."
  $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
  if ($tar) {
    & tar.exe -xf $zip -C $SdkRoot
  } else {
    Expand-Archive -Path $zip -DestinationPath $SdkRoot -Force
  }

  $flutterBat = Join-Path $SdkRoot "flutter\bin\flutter.bat"
}

if (-not (Test-Path $flutterBat)) {
  throw "Could not find flutter.bat at $flutterBat. Free disk space and retry, or install Flutter from https://docs.flutter.dev/get-started/install/windows"
}

Write-Host "Using Flutter: $flutterBat"
& $flutterBat --version
Set-Location $projectRoot
& $flutterBat create . --project-name coach_sessions
& $flutterBat pub get
Write-Host "Bootstrap finished. Next: flutter doctor   then   flutter run   (SDK: $flutterBat)"
