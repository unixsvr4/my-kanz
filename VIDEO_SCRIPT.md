# VIDEO_SCRIPT.md — 2-minute demo (Kanz submission rules compliant)

**Format targets**: MP4 · landscape 16:9 · 1–3 min (this script ≈ 2:00) · 50–200 MB.
**Rule satisfied**: web apps must show *"AI responding with feature switching"* —
scenes 5–7 are exactly that (three distinct AI features, run back-to-back, real
streaming output). **Nothing prohibited**: no slides, no "I plan to…", no
third-party demos, no bare links.

**Core message this cut is built to land, in order of emphasis:**
1. KanzMatch is an ATS (applicant-tracking-system) analyzer.
2. It runs entirely in the browser, at zero cost — no server, ever.
3. The AI layer (Claude) is optional — a precision add-on, not a dependency.
4. It is built for every talent: bilingual English/Arabic with a genuine RTL
   layout, not just a keyword tool for one language or one profession.

## Recording setup (macOS)

```bash
screenshots/scripts/00_start_server.sh   # serve the app at http://localhost:8000
screenshots/scripts/01_open_app.sh       # opens it in your default browser
```

Keep the browser at 100% zoom; hide the bookmarks bar; use a clean profile
(no unrelated tabs visible).

**Recording with QuickTime Player — do this every time, in order:**

1. `File → New Screen Recording` (don't hit record yet — this only opens the
   control bar).
2. Click the small **˅ arrow** next to the red record button → under
   **Microphone**, pick your actual mic. It defaults to **None**, which
   records with no audio and can't be fixed afterward — this is the #1
   silent-video mistake. Also confirm **System Settings → Privacy & Security
   → Microphone** has QuickTime Player enabled; if it's off there, the
   dropdown pick is silently ignored.
3. Click-drag to select just the browser window (not the full screen) so the
   framing stays tight on the app, then click **Start Recording**.
4. Talk through the script below in one take.
5. **Stop**: click the stop icon in the menu bar (near the clock/Wi-Fi
   icons), or ⌘+Ctrl+Esc, or switch to QuickTime Player and use its stop
   control.
6. QuickTime opens the recording in a player window automatically. Save it:
   `File → Save` (⌘S) → name it (e.g. `kanz_demo_raw.mov`) and save into
   `my-kanz/`. This is a `.mov`, not the `.mp4` the submission wants.
7. Convert to MP4 (also compresses — a raw `.mov` can be large):
   ```bash
   ffmpeg -i kanz_demo_raw.mov -vcodec h264 -acodec aac -crf 23 demo.mp4
   ```
   Check the size is under 200 MB: `ls -lh demo.mp4`. If it's still too big,
   lower quality further with a higher `-crf` (e.g. `28`).
8. When you're fully done recording (including any re-takes):
   `screenshots/scripts/99_stop_server.sh` — otherwise the next
   `http.server` run fails with "Address already in use".

Have ready before recording: samples load with one click (built-in); your
Anthropic API key on the clipboard; rehearse the language-toggle click once so
it isn't fumbled on camera. Speak in a measured, confident register — this is
a product statement, not a casual walkthrough.

## Script

| # | Time | On screen | Say (voiceover) |
|---|---|---|---|
| 1 | 0:00–0:12 | App open in browser, cursor idle on the clean landing state | "KanzMatch is an ATS analyzer that runs entirely inside your browser — no server, no signup, no cost to operate. It's built for every talent, in English or Arabic." |
| 2 | 0:12–0:30 | Click **Load sample JD**, **Load sample resume**, then **Analyze match**. Bars animate, score appears | "Paste any job description and any resume, and press Analyze. In under a second, a corpus-tuned scoring engine rates keyword coverage, structure, and experience — the same dimensions a real applicant-tracking system uses before a human ever opens the resume." |
| 3 | 0:30–0:48 | Scroll to chips; hover matched, then missing | "The result is actionable, not just a number: exactly which skills matched, and which ones the posting asks for that the resume never states. An honest edit list — nothing guessed, nothing fabricated." |
| 4 | 0:48–1:05 | Click the 🌐 language toggle. UI flips to Arabic with full right-to-left layout | "And because talent isn't limited to one language, KanzMatch is fully bilingual. One click switches the entire interface to Arabic with a genuine right-to-left layout — the scoring engine itself understands Arabic job descriptions and resumes, not only the labels." |
| 5 | 1:05–1:20 | Switch back to English. Scroll to the AI coach section, paste API key, tab **✍️ Rewrite my summary** → **Run AI feature**. Text streams live | "An AI coach is available — entirely optional. With your own Anthropic API key, Claude rewrites the summary in the job's own vocabulary, hard-ruled to never invent experience that isn't there." |
| 6 | 1:20–1:37 | Switch tab to **🧭 Gap-closing plan** → Run. New stream | "Switch features: a thirty-day plan to close the real gaps this scan found — what to learn, and the honest resume line to write once it's done." |
| 7 | 1:37–1:52 | Switch tab to **✉️ Cover-letter opener** → Run. Point at the cost line under the output | "A third feature drafts a cover-letter opening grounded only in real facts from the resume. Notice the cost line — every AI feature run in this demo cost a fraction of one cent, because it only runs when you choose to use it." |
| 8 | 1:52–2:00 | Rest on the score screen | "Zero infrastructure. Zero cost to run. Every talent, either language, powered by Claude only when you want it. This is KanzMatch." |

## Why this passes AI video verification

- The app is **actively producing output** on camera (scores computed, UI
  language switching live, three distinct AI features streaming) — the core
  thing the verifier checks.
- "Feature switching" is literal: three AI tabs, three different Claude
  behaviors, run back-to-back in one take (scenes 5–7).
- The bilingual/RTL switch (scene 4) is a bonus differentiator beat, not a
  substitute for the AI-switching requirement — it demonstrates the app
  responding to input, but the three AI tabs are what satisfies the rule.
- Every frame is the real running app or its live output; no mockups, no
  slides.
