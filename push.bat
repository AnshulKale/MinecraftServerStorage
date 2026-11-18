
@echo off
setlocal EnableExtensions
cd /d "%~dp0"

call config.bat

echo Checking phone...
"%ADB%" get-state >nul 2>&1
if errorlevel 1 (
    echo ERROR: Phone not detected.
    pause
    exit /b 1
)

echo Checking lock...
if not exist LOCK.txt (
    echo ERROR: No lock found. Refusing to push.
    pause
    exit /b 1
)

set "LOCKOWNER="
set /p LOCKOWNER=<LOCK.txt

if /i not "%LOCKOWNER%"=="%PLAYER_NAME%" (
    echo BLOCKED: %LOCKOWNER% holds the lock.
    pause
    exit /b 1
)

echo Stopping Minecraft...
"%ADB%" shell am force-stop com.mojang.minecraftpe
timeout /t 2 >nul

set "PHONE_WORLD=%MC_WORLDS_PATH%/%WORLD_FOLDER%"

echo Verifying phone world...
"%ADB%" shell "[ -f '%PHONE_WORLD%/level.dat' ]"
if errorlevel 1 (
    echo ERROR: World not found.
    pause
    exit /b 1
)

echo Creating temporary backup...
if exist world_new rmdir /s /q world_new
mkdir world_new

echo Copying world from phone...
"%ADB%" pull "%PHONE_WORLD%/." "world_new/"
if errorlevel 1 (
    echo ERROR: Transfer failed. Existing backup preserved.
    rmdir /s /q world_new
    pause
    exit /b 1
)

if not exist world_new\level.dat (
    echo ERROR: level.dat missing.
    rmdir /s /q world_new
    pause
    exit /b 1
)

echo Replacing previous backup...
if exist world_old rmdir /s /q world_old
if exist world ren world world_old
ren world_new world

if errorlevel 1 (
    echo ERROR: Replacement failed.
    if exist world_old ren world_old world
    pause
    exit /b 1
)

echo Uploading to GitHub...
git add world
git commit -m "%PLAYER_NAME% played - %date% %time%"
if errorlevel 1 (
    echo ERROR: Commit failed. Lock remains active.
    pause
    exit /b 1
)

git push
if errorlevel 1 (
    echo ERROR: Push failed. Lock remains active.
    echo Do not allow another player to pull.
    pause
    exit /b 1
)

echo Releasing lock...
git rm LOCK.txt
git commit -m "Release lock: %PLAYER_NAME%"
if errorlevel 1 (
    echo ERROR: Lock removal commit failed.
    pause
    exit /b 1
)

git push
if errorlevel 1 (
    echo ERROR: Lock release push failed.
    pause
    exit /b 1
)

echo.
echo SUCCESS: World uploaded and lock released.
echo Your world_old folder is retained as a local backup.
pause
