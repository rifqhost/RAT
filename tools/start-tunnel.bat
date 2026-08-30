@echo off
REM Start a FREE Cloudflare *quick tunnel* so the RMODZ server on this PC is
REM reachable from anywhere (any phone, any network). Media stays peer-to-peer
REM via WebRTC/STUN/TURN; only the signaling WS is relayed by the tunnel.
REM
REM IMPORTANT: The trycloudflare URL CHANGES every restart. Build the APKs with
REM the current URL (see docs/USAGE.md); update the --dart-define if it changes.
REM For a permanent URL you need a named tunnel + your own domain.
cd /d "%~dp0"
if not exist cloudflared.exe (
  echo cloudflared.exe not found. Download it to tools\cloudflared.exe from:
  echo   https://github.com/cloudflare/cloudflared/releases
  pause
  exit /b 1
)
echo Starting Cloudflare Tunnel -^> http://localhost:8080 ...
echo Make sure the server is running first (double-click start-server.bat).
echo.
echo Your public URL is the line like:  https://<random>.trycloudflare.com
echo Keep this window open. Press Ctrl+C to stop.
echo.
cloudflared.exe tunnel --url http://localhost:8080 --no-autoupdate
pause