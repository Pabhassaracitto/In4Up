Write-Host "=== Fix Windows Build for in2up (ffmpeg_kit C1083) ===" -ForegroundColor Cyan

# 1. Clean
Write-Host "`n[1/4] flutter clean..." -ForegroundColor Yellow
flutter clean
if (Test-Path "build") { Remove-Item -Recurse -Force build; Write-Host "Removed build/" }
if (Test-Path "windows/flutter/ephemeral") { Remove-Item -Recurse -Force windows/flutter/ephemeral; Write-Host "Removed windows/flutter/ephemeral" }

# 2. Purge old ffmpeg_kit cache (fix header missing)
$pubCache = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev"
if (Test-Path $pubCache) {
    Write-Host "`n[2/4] Purging old ffmpeg_kit pub cache..." -ForegroundColor Yellow
    Get-ChildItem $pubCache -Directory -Filter "ffmpeg_kit_flutter_new-*" | ForEach-Object {
        Write-Host "Removing $($_.Name)"
        Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "`n[2/4] Pub cache not found at $pubCache, skipping" -ForegroundColor Gray
}

# 3. pub get (will fetch 4.6.2)
Write-Host "`n[3/4] flutter pub get (expect ffmpeg_kit_flutter_new 4.6.2)..." -ForegroundColor Yellow
flutter pub get

# Verify version
Write-Host "`nVerifying ffmpeg_kit version:" -ForegroundColor Yellow
flutter pub deps | Select-String -Pattern "ffmpeg_kit_flutter_new" -Context 0,2

# 4. Check ffmpeg binary
Write-Host "`n[4/4] Checking ffmpeg binary for Desktop..." -ForegroundColor Yellow
$exeChecks = @(
    "windows/libs/ffmpeg.exe",
    "windows/libs/ffmpeg/bin/ffmpeg.exe",
    "C:\ffmpeg\bin\ffmpeg.exe"
)
$found = $false
foreach ($p in $exeChecks) {
    if (Test-Path $p) { Write-Host "Found: $p" -ForegroundColor Green; $found = $true }
}
if (-not $found) {
    Write-Host "ffmpeg.exe NOT found in windows/libs/ — Desktop audio conversion will need ffmpeg in PATH or FFMPEG_PATH env." -ForegroundColor Red
    Write-Host "Download from https://github.com/BtbN/FFmpeg-Builds/releases and place bin/ffmpeg.exe into windows/libs/" -ForegroundColor Cyan
} else {
    Write-Host "ffmpeg.exe check OK" -ForegroundColor Green
}

Write-Host "`n=== Done. Now run: flutter run -d windows ===" -ForegroundColor Cyan
Write-Host "If still C1083, set env: `$env:FFMPEGKIT_LOCAL_DIR='E:\path\to\bundle' (optional) or ensure internet for prebuilt download." -ForegroundColor Gray
