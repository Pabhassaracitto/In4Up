@echo off
echo Exporting Flutter project with native configurations...

REM Xuất code Dart
echo ===== DART CODE ===== > code_export.txt
for /r lib %%i in (*.dart) do (
    echo === %%i === >> code_export.txt
    type "%%i" >> code_export.txt
    echo. >> code_export.txt
)
type pubspec.yaml >> code_export.txt
echo Dart code exported: code_export.txt

REM Xuất native configs
echo ===== NATIVE CONFIGS ===== > native_export.txt

REM Android
if exist android (
    echo === ANDROID === >> native_export.txt
    type android\app\build.gradle >> native_export.txt 2>nul
    echo. >> native_export.txt
)

REM iOS
if exist ios (
    echo === IOS === >> native_export.txt
    type ios\Runner\Info.plist >> native_export.txt 2>nul
    echo. >> native_export.txt
)

REM Windows
if exist windows (
    echo === WINDOWS === >> native_export.txt
    type windows\CMakeLists.txt >> native_export.txt 2>nul
    echo. >> native_export.txt
)

REM Native folder
if exist native (
    echo === NATIVE FOLDER === >> native_export.txt
    for /r native %%i in (*.cpp,*.c,*.h,*.cmake,*.txt) do (
        echo === %%i === >> native_export.txt
        type "%%i" >> native_export.txt
        echo. >> native_export.txt
    )
)

echo Native configs exported: native_export.txt
echo.
echo ALL EXPORTS COMPLETED!
pause