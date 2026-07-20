#!/bin/bash
# Captures the Arabic/RTL screenshots: the top of the results view
# (05_arabic_rtl.png) and the AI coach panel + footer after scrolling down
# (06_arabic_ai_panel.png). Run 00_start_server.sh first.
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
OUT="../"

safari_open_clean "0, 0, 1920, 1080"

# IMPORTANT: if Safari had a stale cached copy of index.html loaded from an
# earlier session (e.g. you edited app/index.html after last opening it in
# this Safari window), langBtn / new elements can be silently missing from
# the DOM even though they're in the file on disk. Force-reload once to be
# safe — cheap insurance against a confusing "element not found" debugging
# session.
safari_js 'location.reload(true)' >/dev/null
sleep 1

safari_click jdSample
safari_click rzSample
safari_click run
safari_click langBtn
sleep 0.5

dir_lang=$(safari_js 'document.documentElement.dir + "-" + document.documentElement.lang')
if [[ "$dir_lang" != rtl-ar* ]]; then
  echo "Expected rtl-ar, got: $dir_lang — langBtn may not have wired correctly." >&2
  exit 1
fi

safari_shot "${OUT}05_arabic_rtl.png"

safari_js 'window.scrollTo(0, document.body.scrollHeight)' >/dev/null
sleep 0.3
safari_shot "${OUT}06_arabic_ai_panel.png"

echo "Wrote 05_arabic_rtl.png, 06_arabic_ai_panel.png"
