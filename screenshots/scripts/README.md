# screenshots/scripts — reproducible screenshot automation

Everything in `../` (the 6 PNGs) was captured by scripting Safari and iTerm2
directly from the shell — no manual screenshotting, no test-framework
dependency (Playwright/Puppeteer weren't installed and weren't needed). This
folder is that automation, cleaned up and made reusable, because getting it
right took several false starts worth documenting so the next run is fast.

## Quick start

```bash
cd screenshots/scripts
./00_start_server.sh                # serves app/ at localhost:8000
./01_capture_app_shots.sh           # 01_samples_loaded, 02_score_screen, 03_dark_mode
./02_capture_terminal_shot.sh       # 04_validation_terminal (needs Pillow: pip install pillow)
./03_capture_i18n_shots.sh          # 05_arabic_rtl, 06_arabic_ai_panel
```

First run on a new machine: open `01_capture_app_shots.sh` and uncomment
`safari_enable_js_automation` — Safari blocks `do JavaScript` from Apple
Events by default (Settings → Developer → "Allow JavaScript from Apple
Events"); the helper flips that pref via `defaults write` and restarts
Safari. One-time only.

## Files

| File | Purpose |
|---|---|
| `lib.sh` | Shared Safari/iTerm2 automation functions, sourced by the numbered scripts |
| `00_start_server.sh` | Starts (or restarts) the local static server |
| `01_capture_app_shots.sh` | Light-mode samples, score screen, dark mode |
| `02_capture_terminal_shot.sh` | Runs the RESEARCH.md §3 validation command in a clean iTerm window and screenshots it |
| `run_validation.py` | The actual validation logic (extracts the JS scoring core from `index.html`, runs it in Node) — also just useful on its own, independent of screenshots |
| `03_capture_i18n_shots.sh` | Arabic/RTL UI + AI panel |

## Gotchas this encodes (so you don't rediscover them)

**Always `activate` immediately before `screencapture`, in the same command.**
`screencapture -x` captures the whole screen in current z-order, not "the
active app." If `activate Safari` and `screencapture` run as two separate
tool/shell invocations, whatever's actually driving your terminal (iTerm,
etc.) can regain focus in between and you'll screenshot *that* instead. Every
capture in `lib.sh` (`safari_shot`) does activate → escape → capture as one
atomic AppleScript call.

**`do JavaScript ... in document 1` is not "the window you're looking at."**
Safari's AppleScript `documents` collection is ordered by creation, not
by window stacking order. If a stale/duplicate window exists (e.g. Safari
auto-restored a previous session after being quit/relaunched), `document 1`
can silently point at the *background* one — your clicks appear to do
nothing, or worse, do something invisible. `safari_open_clean` in `lib.sh`
closes any other window whose URL matches the app before proceeding, so
there's only ever one candidate document.

**Don't close windows by a blanket heuristic — match on URL.** An earlier,
cruder version of the cleanup used "close every window with 0 tabs" to kill
a ghost window left over from a Safari restart, and it also closed an
unrelated login tab the user had open (same heuristic matched a window it
shouldn't have). `safari_close_duplicate_app_windows` instead only closes
windows whose *current tab URL* equals the app's URL — it can never touch a
window you have open for something else.

**Stale cache after editing `index.html`.** If you edit the app file and
reuse an already-open Safari window/tab instead of opening a fresh one,
newly-added DOM elements (a new button, say) can be missing even though
they're in the file on disk — Safari served the cached version. `location.reload(true)`
before interacting fixes it; `03_capture_i18n_shots.sh` does this
unconditionally since it's cheap insurance.

**iTerm2 windows don't reliably resize to the pixel bounds you request.**
`create window with default profile` + `set bounds` reports back the bounds
you asked for, but the actual rendered window often snaps to a much smaller
size (profile grid/row constraints). Don't trust the bounds you set — capture
generously and crop by inspecting the actual pixels (see `02_capture_terminal_shot.sh`'s
crop comment), or better, sample pixel colors directly (`PIL.Image.getpixel`)
to find the real content/window boundary instead of guessing coordinates.

**iTerm session transparency bleeds other windows into your crop.** If your
iTerm profile has background transparency on, a screenshot of a small
foreground iTerm window shows whatever's behind it through the translucent
parts. `iterm_run_isolated` sets `transparency to 0` on the new session
before capturing.

**Theme/language toggles that *cycle* aren't idempotent.** The app's theme
button cycles light → dark → OS-default; clicking it once doesn't
deterministically land on "dark" if the OS is already dark-mode. Check the
resulting state (`data-theme`, or `dir`/`lang` for the language toggle) and
click again if you didn't land where you expected, rather than assuming N
clicks == a specific state.

**Trust pixel data over your own read of a screenshot thumbnail.** While
debugging a "dark mode looks light" issue, `getComputedStyle` and `PIL`
pixel sampling both confirmed the page really was dark — the mismatch was
in how the screenshot rendered small in review, not a real bug. If a
screenshot "looks wrong," sample actual pixel values (`PIL.Image.getpixel`)
before spending time debugging the app.
