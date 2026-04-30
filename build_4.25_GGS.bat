@echo off

:: Self-elevate to admin if not already
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

:: Prompt for the team member's Perforce workspace root (every workspace
:: contains a Dev\ subdir with the UE 4.25 engine).
:: Override non-interactively by setting P4_ROOT before running, e.g.:
:: set "P4_ROOT=D:\projects\GUILTY-GEAR-Strive-P4" && build_4.25_GGS.bat
if not defined P4_ROOT (
    set /p "P4_ROOT=Enter your Perforce workspace root (e.g. D:\projects\GUILTY-GEAR-Strive-P4): "
)
:: Strip surrounding quotes if the user pasted a quoted path
set P4_ROOT=%P4_ROOT:"=%
if "%P4_ROOT%"=="" (
    echo error: workspace root cannot be empty.
    pause
    exit /b 1
)
if not exist "%P4_ROOT%\Dev\Engine\Build\BatchFiles\RunUAT.bat" (
    echo error: "%P4_ROOT%\Dev\Engine\Build\BatchFiles\RunUAT.bat" not found.
    echo Make sure P4_ROOT points to the workspace root that contains the Dev\ subdir.
    pause
    exit /b 1
)

:: Clear read-only flags on all engine build artifact dirs (Perforce sets files read-only)
echo Clearing read-only attributes on engine build directories...
attrib -R "%P4_ROOT%\Dev\Engine\Binaries\*" /S /D 2>nul
attrib -R "%P4_ROOT%\Dev\Engine\Platforms\*" /S /D 2>nul
attrib -R "%P4_ROOT%\Dev\Engine\Source\Programs\*" /S /D 2>nul

:: Suppress MSVC warnings that UE 4.25 engine code triggers with newer VS toolchains
:: CL is prepended to cl.exe args, _CL_ is appended (gets final precedence over /WX)
set CL=/wd4800 /wd5038 /wd4458
set _CL_=/wd4800 /wd5038 /wd4458

call "%P4_ROOT%\Dev\Engine\Build\BatchFiles\RunUAT.bat" BuildPlugin -Plugin="%~dp0UnrealClaude\UnrealClaude.uplugin" -Package="%~dp0Build_4.25" -TargetPlatforms=Win64

pause
