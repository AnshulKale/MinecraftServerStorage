
@echo off
setlocal
cd /d "%~dp0"

if not exist config.bat (
    copy config.example.bat config.bat >nul
)

call config.bat

echo.
echo ===== MINECRAFT WORLDS =====
echo.

"%ADB%" shell ls "%MC_WORLDS_PATH%"

echo.
echo ===== WORLD NAMES =====
echo.

for /f "delims=" %%F in ('adb shell ls /sdcard/Android/data/com.mojang.minecraftpe/files/games/com.mojang/minecraftWorlds') do (
    echo Folder: %%F
    adb shell cat "/sdcard/Android/data/com.mojang.minecraftpe/files/games/com.mojang/minecraftWorlds/%%F/levelname.txt"
    echo.
)

echo Script finished.
pause
