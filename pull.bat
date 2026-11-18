
@echo off
setlocal EnableExtensions
cd /d "%~dp0"

if not exist config.bat (
    echo ERROR: config.bat missing.
    pause
    exit /b 1
)

call config.bat

echo Checking for local Git changes...

for /f "delims=" %%A in ('git status --porcelain') do (
    echo ERROR: Commit or resolve local changes first.
    echo Pending change: %%A
    pause
    exit /b 1
)

echo Checking phone...
"%ADB%" get-state >nul 2>&1
if errorlevel 1 (
    echo ERROR: Phone not detected.
    pause
    exit /b 1
)

echo Fetching latest repository...
git pull --ff-only
if errorlevel 1 (
    echo ERROR: Git pull failed.
    pause
    exit /b 1
)

if exist LOCK.txt (
    set "LOCKOWNER="
    set /p LOCKOWNER=<LOCK.txt
    if /i not "%LOCKOWNER%"=="%PLAYER_NAME%" (
        echo BLOCKED: Another player holds the lock.
        pause
        exit /b 1
    )
)

if not exist world\level.dat (
    echo ERROR: No world backup found.
    pause
    exit /b 1
)

echo Stopping Minecraft...
"%ADB%" shell am force-stop com.mojang.minecraftpe

set "PHONE_WORLD=%MC_WORLDS_PATH%/%WORLD_FOLDER%"

echo Preparing phone...
"%ADB%" shell mkdir -p "%PHONE_WORLD%"
if errorlevel 1 goto failed

echo Copying world...
"%ADB%" push "world/." "%PHONE_WORLD%/"
if errorlevel 1 goto failed

echo Verifying world...
"%ADB%" shell "[ -f '%PHONE_WORLD%/level.dat' ]"
if errorlevel 1 goto failed

echo Creating lock...
>LOCK.txt echo %PLAYER_NAME%

git add LOCK.txt
git commit -m "LOCK: %PLAYER_NAME% started playing"
if errorlevel 1 goto failed

git push
if errorlevel 1 (
    echo ERROR: Lock push failed.
    echo Do not play. Check GitHub and reconcile the lock.
    pause
    exit /b 1
)

echo.
echo SUCCESS: World downloaded and lock acquired.
echo You can now open Minecraft.
pause
exit /b 0

:failed
echo ERROR: Operation failed. Do not play.
pause
exit /b 1
