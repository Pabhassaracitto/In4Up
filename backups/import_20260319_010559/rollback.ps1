# Rollback script - 20260319_010559
param([string]$Root = 'D:\4_DU_AN\flutterprojects\vipsound')

Copy-Item "D:\4_DU_AN\flutterprojects\vipsound\backups\import_20260319_010559\_originals\lib/features/youtube/youtube_explorer_screen.dart" "D:\4_DU_AN\flutterprojects\vipsound\lib/features/youtube/youtube_explorer_screen.dart" -Force
Remove-Item "D:\4_DU_AN\flutterprojects\vipsound\lib/features/youtube/yt_player_screen.dart" -Force -EA SilentlyContinue

Write-Host 'Rollback complete!' -ForegroundColor Green

