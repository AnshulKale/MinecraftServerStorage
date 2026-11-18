
@echo off
setlocal EnableExtensions
cd /d "%~dp0"

call config.bat

echo Checking Git and phone...

git status --porcelain > status.tmp
for %%A in (status.tmp) do if %%~zA GTR 0 (
    del status.tmp
    echo ERROR: Commit or resolve local changes first.
    pause
    exit /b 1
)
del status.tmp

"%ADB%" get-state >nul 2>&1
if errorlevel 1 (
    echo ERROR: Phone not detected.
    pause
    exit /b 1
)

echo Fetching latest backup...
git pull --ff-only
if errorlevel 1 goto failed

if exist LOCK.txt (
    echo BLOCKED: Another player holds the lock.
    type LOCK.txt
    pause
    exit /b 1
)

if not exist world\level.dat (
    echo ERROR: No world backup found.
    pause
    exit /b 1
)

echo Acquiring lock...
>LOCK.txt echo %PLAYER_NAME%

git add LOCK.txt
git commit -m "LOCK: %PLAYER_NAME% started playing"
if errorlevel 1 goto failed

git push
if errorlevel 1 (
    echo ERROR: Lock push failed.
    echo Do NOT play. Check GitHub before retrying.
    pause
    exit /b 1
)

echo Stopping Minecraft...
"%ADB%" shell am force-stop com.mojang.minecraftpe

set "PHONE_WORLD=%MC_WORLDS_PATH%/%WORLD_FOLDER%"

echo Preparing phone world...
"%ADB%" shell mkdir -p "%PHONE_WORLD%"

if errorlevel 1 goto failed

echo Copying world...
"%ADB%" push "world/." "%PHONE_WORLD%/"

if errorlevel 1 (
    echo ERROR: Transfer failed. Lock remains active.
    pause
    exit /b 1
)

"%ADB%" shell "[ -f '%PHONE_WORLD%/level.dat' ]"
if errorlevel 1 (
    echo ERROR: World verification failed.
    pause
    exit /b 1
)

echo.
echo SUCCESS: World downloaded and verified.
echo You can now open Minecraft.
pause
exit /b 0

:failed
echo.
echo ERROR: Operation failed. Check Git status and GitHub.
pause
exit /b 1
