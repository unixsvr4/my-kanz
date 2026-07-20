#!/bin/bash
# Starts the local static server the app screenshots are taken against.
# Safe to re-run — kills any previous instance on the same port first.
set -euo pipefail
cd "$(dirname "$0")/../.."   # -> my-kanz/

PORT="${1:-8000}"
pkill -f "http.server -d $(pwd)/app $PORT" 2>/dev/null || true
sleep 0.3
python3 -m http.server -d app "$PORT" &>/tmp/kanz_server.log &
sleep 1
curl -sfI "http://localhost:$PORT/index.html" >/dev/null \
  && echo "Serving app/ at http://localhost:$PORT" \
  || { echo "Server failed to start — check /tmp/kanz_server.log"; exit 1; }
