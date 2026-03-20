# Rollback script - 20260318_204643
param([string]$Root = 'D:\4_DU_AN\flutterprojects\vipsound')

Remove-Item "D:\4_DU_AN\flutterprojects\vipsound\lib/features/youtube/youtube_explorer_screen.dart" -Force -EA SilentlyContinue
Copy-Item "D:\4_DU_AN\flutterprojects\vipsound\backups\import_20260318_204643\_originals\lib/screens/tools/word_list/word_list_screen.dart" "D:\4_DU_AN\flutterprojects\vipsound\lib/screens/tools/word_list/word_list_screen.dart" -Force
Copy-Item "D:\4_DU_AN\flutterprojects\vipsound\backups\import_20260318_204643\_originals\lib/features/web_reader/web_reader_screen.dart" "D:\4_DU_AN\flutterprojects\vipsound\lib/features/web_reader/web_reader_screen.dart" -Force
Copy-Item "D:\4_DU_AN\flutterprojects\vipsound\backups\import_20260318_204643\_originals\lib/screens/main_shell.dart" "D:\4_DU_AN\flutterprojects\vipsound\lib/screens/main_shell.dart" -Force

Write-Host 'Rollback complete!' -ForegroundColor Green

