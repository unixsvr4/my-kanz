#!/bin/bash
# Captures the "headless validation running" screenshot (04_validation_terminal.png)
# in a clean, dedicated iTerm2 window — deliberately NOT reusing your actual
# terminal session, which is almost certainly cluttered with unrelated tabs
# you don't want in a hackathon screenshot.
#
# Requires: iTerm2, Python + Pillow (`pip install pillow`), Node.
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

CMD="python3 $(pwd)/run_validation.py"
wid=$(iterm_run_isolated "clear && $CMD" "60, 60, 1200, 400")
sleep 1
iterm_shot_raw "$wid" /tmp/kanz_term_raw.png
iterm_close "$wid"

# Crop: iTerm2 windows don't reliably grow to the requested pixel bounds
# (see lib.sh), so the real content sits in roughly the top ~100-160px of
# the window relative to its (60,60) origin. This crop box was tuned by
# inspection for a 2-line command output at the default iTerm profile font
# size — if your output has more/fewer lines, or you changed the font size,
# widen CROP_BOTTOM and re-run; check the result and narrow it back down
# rather than guessing blind (see README's "why a paint-over, not a crop" note).
python3 - <<'EOF'
from PIL import Image
im = Image.open("/tmp/kanz_term_raw.png")
CROP = (60, 60, 1200, 168)   # (left, top, right, bottom) — tune per above
im.crop(CROP).save("../04_validation_terminal.png")
print("Wrote 04_validation_terminal.png —", im.crop(CROP).size)
print("If the bottom line looks clipped or another window's tab bar peeks")
print("in at the bottom edge, adjust CROP_BOTTOM in this script and re-run.")
EOF
