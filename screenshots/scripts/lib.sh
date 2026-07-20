#!/bin/bash
# lib.sh — shared helpers for scripting Safari + iTerm2 screenshots on macOS.
# Source this from another script: `source "$(dirname "$0")/lib.sh"`
#
# Why this exists: driving a real browser via AppleScript to capture
# screenshots has several non-obvious failure modes (see ../README.md for the
# full write-up of each one). These functions bake in the fixes so you don't
# have to rediscover them.

set -euo pipefail

APP_URL="${APP_URL:-http://localhost:8000/index.html}"

# One-time prerequisite: Safari blocks `do JavaScript` from Apple Events by
# default. This flips the preference and restarts Safari. Only needs to run
# once per machine (or after a macOS/Safari update resets prefs).
safari_enable_js_automation() {
  osascript -e 'tell application "Safari" to quit' 2>/dev/null || true
  sleep 1
  defaults write com.apple.Safari AllowJavaScriptFromAppleEvents -bool true
}

# Opens exactly ONE Safari window at the given bounds and navigates it to
# APP_URL. Uses `make new document` — if Safari was just relaunched (e.g. by
# safari_enable_js_automation) it may auto-restore a previous session's
# windows, so this ALSO calls safari_close_duplicate_app_windows after, which
# only closes windows whose URL matches APP_URL (never touches unrelated
# windows/tabs the user had open — see the README's "don't nuke user state"
# note).
safari_open_clean() {
  local bounds="${1:-0, 0, 1920, 1080}"
  osascript -e "
    tell application \"Safari\"
      activate
      make new document
      set URL of document 1 to \"$APP_URL\"
      set bounds of window 1 to {$bounds}
    end tell"
  sleep 2
  safari_close_duplicate_app_windows
  # Clear persisted state (language, remembered key) then reload so the page
  # re-initializes fresh — clearing localStorage alone doesn't change the
  # already-running page's in-memory LANG variable, only a reload does.
  safari_reset_app_state
  safari_js "location.reload(true)" >/dev/null
  sleep 1
}

# Closes every Safari window whose current tab URL is APP_URL, EXCEPT the
# frontmost one. Deliberately URL-scoped: a blanket "close windows with 0
# tabs" pass once closed an unrelated login tab the user had open (a ghost
# window's title still matched our app's title even though its tab count was
# 0). Matching on URL instead of window count/title is what's actually safe.
safari_close_duplicate_app_windows() {
  osascript -e "
    tell application \"Safari\"
      set frontURL to \"\"
      try
        set frontURL to URL of document 1
      end try
      set n to count of windows
      repeat with i from n to 2 by -1
        try
          if URL of document i is \"$APP_URL\" then close window i
        end try
      end repeat
    end tell" 2>/dev/null || true
}

# Runs a JS expression in the app's Safari document and returns its result.
# Usage: safari_js 'document.getElementById("themeBtn").click()'
# Double quotes inside the JS are escaped for you — write normal JS with
# normal double-quoted strings, not pre-escaped AppleScript-safe JS.
safari_js() {
  local js_escaped=${1//\"/\\\"}
  osascript -e "tell application \"Safari\" to do JavaScript \"$js_escaped\" in document 1"
}

# Clicks a button/input by id. Usage: safari_click jdSample
safari_click() {
  safari_js "document.getElementById('$1').click(); 'ok'"
}

# Activates Safari, clears any focused-address-bar highlight (Escape),  and
# takes a full-screen capture — all inside ONE osascript/shell invocation.
# This matters: if "activate Safari" and "screencapture" run as separate tool
# calls, whatever GUI app is driving your automation (iTerm, Claude Code's
# terminal, etc.) regains focus in between and you screenshot THAT instead.
# Always keep activate -> capture atomic.
safari_shot() {
  local outfile="$1"
  osascript -e 'tell application "Safari" to activate' \
    -e 'delay 0.3' \
    -e 'tell application "System Events" to key code 53' \
    -e 'delay 0.3'
  screencapture -x "$outfile"
}

# Runs a shell command in a DEDICATED new iTerm2 window (not a tab in your
# existing, possibly-cluttered session) and leaves it positioned/sized for a
# screenshot. Prints the new window's numeric id on stdout — pass it to
# iterm_shot_and_close to capture + clean up.
iterm_run_isolated() {
  local cmd="$1" bounds="${2:-60, 60, 1200, 400}"
  local wid
  wid=$(osascript -e "
    tell application \"iTerm2\"
      set newWindow to (create window with default profile)
      tell current session of newWindow
        set transparency to 0
      end tell
      tell current session of newWindow
        write text \"$cmd\"
      end tell
      return id of newWindow
    end tell")
  sleep 2
  osascript -e "
    tell application \"iTerm2\"
      repeat with w in windows
        if (id of w) is $wid then set bounds of w to {$bounds}
      end repeat
    end tell"
  sleep 0.3
  echo "$wid"
}

# Captures the iTerm window `wid` and crops to (approximately) just its
# content — NOT the full bounds you requested. iTerm2 windows created via
# `create window with default profile` don't reliably grow to the pixel
# height you asked for (they snap to the profile's row/column grid instead),
# so the real content area is usually much shorter than the requested bounds.
# Rather than guess a fixed crop box, this over-captures a generous region and
# leaves the exact crop to you (see README "why we don't auto-crop terminal
# shots precisely"). Requires Python + Pillow (`pip install pillow`).
iterm_shot_raw() {
  local wid="$1" outfile="$2"
  osascript -e "
    tell application \"iTerm2\"
      repeat with w in windows
        if (id of w) is $wid then select w
      end repeat
      activate
    end tell"
  sleep 0.3
  screencapture -x "$outfile"
}

# Clears app-persisted localStorage (language choice, remembered API key) so
# every script run starts from the same deterministic state, regardless of
# what a previous manual session or script run left behind. The language
# toggle intentionally persists across reloads for real users — which means
# a screenshot script that doesn't reset it will silently inherit whatever
# language the LAST session ended in. Call this before assuming "fresh load
# == English/light".
safari_reset_app_state() {
  safari_js "localStorage.removeItem('kanzmatch_lang'); localStorage.removeItem('kanzmatch_key')" >/dev/null
}

iterm_close() {
  local wid="$1"
  osascript -e "
    tell application \"iTerm2\"
      repeat with w in windows
        if (id of w) is $wid then close w
      end repeat
    end tell" 2>/dev/null || true
}
