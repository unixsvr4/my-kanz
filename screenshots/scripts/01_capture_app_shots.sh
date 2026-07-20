#!/bin/bash
# Captures the three "core app" screenshots: samples loaded (light mode),
# the score screen (which also shows the matched/missing chip panels), and
# dark mode. Run 00_start_server.sh first.
#
# First run on a machine: uncomment the safari_enable_js_automation line
# below (one-time; it quits and restarts Safari).
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
OUT="../"

# safari_enable_js_automation   # uncomment on first run on a new machine

safari_open_clean "0, 0, 1920, 1080"

# 1. Light mode, samples loaded, before Analyze
safari_click jdSample
safari_click rzSample
sleep 0.3
safari_shot "${OUT}01_samples_loaded.png"

# 2. Score screen (also captures the matched/missing chip panels in the
#    same frame — no need for a separate shot)
safari_click run
sleep 1.5
safari_shot "${OUT}02_score_screen.png"

# 3. Dark mode. The theme button CYCLES: explicit "light" -> explicit
#    "dark" -> OS default. If the OS is already in dark mode (common), the
#    FIRST click can land on explicit "light" instead of "dark" — always
#    check the resulting data-theme and click again if needed rather than
#    assuming one click == dark.
theme=$(safari_js 'document.getElementById("themeBtn").click(); document.documentElement.getAttribute("data-theme")')
if [[ "$theme" != *dark* ]]; then
  safari_js 'document.getElementById("themeBtn").click(); document.documentElement.getAttribute("data-theme")' >/dev/null
fi
sleep 0.3
safari_shot "${OUT}03_dark_mode.png"

echo "Wrote 01_samples_loaded.png, 02_score_screen.png, 03_dark_mode.png"
