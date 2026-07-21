#!/bin/bash
# Stops the local static server started by 00_start_server.sh (or any plain
# `python3 -m http.server -d app <port>` run from the my-kanz root). Safe to
# re-run — no-op if nothing is listening.
set -euo pipefail
cd "$(dirname "$0")/../.."   # -> my-kanz/

PORT="${1:-8000}"

PIDS=$(pgrep -f "http.server -d $(pwd)/app $PORT" 2>/dev/null || true)
if [ -z "$PIDS" ]; then
  # Fall back to whatever process actually holds the port, in case the
  # server was started manually (different cwd/args than the pattern above).
  PIDS=$(lsof -ti "tcp:$PORT" 2>/dev/null || true)
fi

if [ -z "$PIDS" ]; then
  echo "Nothing listening on port $PORT."
  exit 0
fi

kill $PIDS 2>/dev/null || true
sleep 0.3
echo "Stopped server on port $PORT (pid: $PIDS)."
