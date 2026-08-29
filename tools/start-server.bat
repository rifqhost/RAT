@echo off
REM Start the RMODZ signaling server. Runs the compiled build; requires
REM `npm install` and `npm run build` to have been run at least once.
cd /d "%~dp0..\server"
echo Starting RMODZ server on http://localhost:8080 ...
echo Press Ctrl+C to stop.
call node dist\index.js
