@echo off
echo ====================================================
echo   DANG CAP NHAT TOAN BO PACKAGES CHO VIPSOUND
echo ====================================================

:: Run pub get for the root project
echo [1/2] Dang chay pub get cho du an goc...
call flutter pub get

:: Find and run pub get for all sub-packages in 'packages' folder
if exist "packages" (
    echo [2/2] Dang quet cac thu muc trong /packages...
    for /d %%i in (packages\*) do (
        if exist "%%i\pubspec.yaml" (
            echo --- Dang cap nhat: %%i
            cd %%i
            call flutter pub get
            cd ..\..
        )
    )
)

echo ====================================================
echo   HOAN THANH! NHAN PHIM BAT KY DE THOAT.
echo ====================================================
pause