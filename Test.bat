@echo off
title Forge of the Eight Stones - Tests
cd /d "%~dp0"

echo Running the automated test. A window will not open.
echo.
"tools\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%CD%" res://tests/smoke_test.tscn
echo.
pause
