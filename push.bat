
@echo off
setlocal EnableExtensions
cd /d "%~dp0"

call config.bat

echo Checking Git status...
for /f "delims=" %%A in ('git status --porcelain') do (
    echo ERROR: Local changes detected: %%A
    echo Resolve them before pushing.
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

echo Checking lock...
if not exist LOCK.txt (
    echo ERROR: No lock found.
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

set "PHONE_WORLD=%MC_WORLDS_PATH%/%WORLD_FOLDER%"
set "TEMP_ROOT=%TEMP%\MCWorld_%RANDOM%"

echo Stopping Minecraft...
"%ADB%" shell am force-stop com.mojang.minecraftpe
timeout /t 2 >nul

echo Verifying phone world...
"%ADB%" shell "[ -f '%PHONE_WORLD%/level.dat' ]"
if errorlevel 1 goto failed

echo Downloading world to temporary backup...
mkdir "%TEMP_ROOT%\download"
if errorlevel 1 goto failed

"%ADB%" pull "%PHONE_WORLD%/." "%TEMP_ROOT%\download\"
if errorlevel 1 goto failed

if not exist "%TEMP_ROOT%\download\level.dat" goto failed

echo Preserving previous local backup...
if exist world (
    move world "%TEMP_ROOT%\previous_world"
    if errorlevel 1 goto failed
)

echo Installing downloaded world...
move "%TEMP_ROOT%\download" world
if errorlevel 1 (
    if exist "%TEMP_ROOT%\previous_world" move "%TEMP_ROOT%\previous_world" world
    goto failed
)

echo Staging world changes...
git add world
if errorlevel 1 goto failed

git diff --cached --quiet
if errorlevel 1 (
    echo Creating world backup commit...
    git commit -m "%PLAYER_NAME% played - %date% %time%"
    if errorlevel 1 goto failed
) else (
    echo No world changes detected. Skipping commit.
)

echo Uploading world to GitHub...
git push
if errorlevel 1 (
    echo ERROR: Upload failed. Lock remains active.
    echo Do not let another player play.
    pause
    exit /b 1
)

echo Releasing lock...
git rm LOCK.txt
if errorlevel 1 goto failed

git commit -m "Release lock: %PLAYER_NAME%"
if errorlevel 1 goto failed

git push
if errorlevel 1 (
    echo ERROR: Lock release push failed.
    echo Check GitHub before allowing another player to play.
    pause
    exit /b 1
)

echo.
echo ========================================
echo SUCCESS: World uploaded to GitHub.
echo Lock released.
echo ========================================
echo Previous local backup: %TEMP_ROOT%\previous_world
pause
exit /b 0

:failed
echo.
echo ERROR: Operation failed.
echo Do not play or release the lock manually.
echo Check GitHub and local files before retrying.
pause
exit /b 1
