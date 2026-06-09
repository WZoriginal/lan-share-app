@echo off
cd /d "%~dp0"
if not exist "%~dp0lan-share-url.txt" (
  echo Please run start-server.bat first.>"%~dp0lan-share-url.txt"
)
start "" notepad "%~dp0lan-share-url.txt"
