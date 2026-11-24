@echo off
title Forge of the Eight Stones - Editor
cd /d "%~dp0"

if not exist "tools\Godot_v4.7.2-stable_win64.exe" (
    echo.
    echo   The Godot engine is missing from the tools folder.
    echo   Download Godot 4.7 from https://godotengine.org/download
    echo   and unzip Godot_v4.7.2-stable_win64.exe into tools\
    echo.
    pause
    exit /b 1
)

echo Opening the Godot editor. Press F5 inside the editor to play.
start "" "tools\Godot_v4.7.2-stable_win64.exe" -e --path "%CD%"
