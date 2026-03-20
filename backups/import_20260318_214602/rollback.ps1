# Rollback script - 20260318_214602
param([string]$Root = 'D:\4_DU_AN\flutterprojects\vipsound')

Copy-Item "D:\4_DU_AN\flutterprojects\vipsound\backups\import_20260318_214602\_originals\lib/screens/main_shell.dart" "D:\4_DU_AN\flutterprojects\vipsound\lib/screens/main_shell.dart" -Force
Copy-Item "D:\4_DU_AN\flutterprojects\vipsound\backups\import_20260318_214602\_originals\lib/screens/tools/word_list/word_list_controller.dart" "D:\4_DU_AN\flutterprojects\vipsound\lib/screens/tools/word_list/word_list_controller.dart" -Force
Copy-Item "D:\4_DU_AN\flutterprojects\vipsound\backups\import_20260318_214602\_originals\lib/screens/tools/word_list/word_list_screen.dart" "D:\4_DU_AN\flutterprojects\vipsound\lib/screens/tools/word_list/word_list_screen.dart" -Force
Copy-Item "D:\4_DU_AN\flutterprojects\vipsound\backups\import_20260318_214602\_originals\lib/screens/tools/word_list/word_list_models.dart" "D:\4_DU_AN\flutterprojects\vipsound\lib/screens/tools/word_list/word_list_models.dart" -Force
Copy-Item "D:\4_DU_AN\flutterprojects\vipsound\backups\import_20260318_214602\_originals\lib/screens/tools/word_list/loop_count_picker.dart" "D:\4_DU_AN\flutterprojects\vipsound\lib/screens/tools/word_list/loop_count_picker.dart" -Force

Write-Host 'Rollback complete!' -ForegroundColor Green

