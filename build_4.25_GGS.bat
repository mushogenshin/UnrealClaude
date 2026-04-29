@echo off

:: Self-elevate to admin if not already
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

:: Clear read-only flags on all engine build artifact dirs (Perforce sets files read-only)
echo Clearing read-only attributes on engine build directories...
attrib -R "D:\projects\GUILTY-GEAR-Strive-P4\Dev\Engine\Binaries\*" /S /D 2>nul
attrib -R "D:\projects\GUILTY-GEAR-Strive-P4\Dev\Engine\Platforms\*" /S /D 2>nul
attrib -R "D:\projects\GUILTY-GEAR-Strive-P4\Dev\Engine\Source\Programs\*" /S /D 2>nul

:: Suppress MSVC warnings that UE 4.25 engine code triggers with newer VS toolchains
:: CL is prepended to cl.exe args, _CL_ is appended (gets final precedence over /WX)
set CL=/wd4800 /wd5038 /wd4458
set _CL_=/wd4800 /wd5038 /wd4458

call "D:\projects\GUILTY-GEAR-Strive-P4\Dev\Engine\Build\BatchFiles\RunUAT.bat" BuildPlugin -Plugin="D:\projects\UnrealClaude\UnrealClaude\UnrealClaude.uplugin" -Package="D:\projects\UnrealClaude\Build_4.25" -TargetPlatforms=Win64

pause
