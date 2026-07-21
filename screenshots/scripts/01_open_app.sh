#!/bin/bash
# Opens the running app in the default browser. Run 00_start_server.sh first.
set -euo pipefail

PORT="${1:-8000}"
URL="http://localhost:$PORT"

curl -sfI "$URL/index.html" >/dev/null \
  || { echo "Nothing serving at $URL — run 00_start_server.sh first."; exit 1; }

open "$URL"
