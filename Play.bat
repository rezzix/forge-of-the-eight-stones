@echo off
title Forge of the Eight Stones
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

echo Starting Forge of the Eight Stones...
start "" "tools\Godot_v4.7.2-stable_win64.exe" --path "%CD%" res://scenes/main.tscn
