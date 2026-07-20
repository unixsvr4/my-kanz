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
python3 -m http.server -d app 8000     # serve the app at http://localhost:8000
# Record: QuickTime → File → New Screen Recording, 16:9 browser window, mic on.
# Keep the browser at 100% zoom; hide bookmarks bar; use a clean profile.
# If the file exceeds 200 MB: ffmpeg -i raw.mov -vcodec h264 -crf 23 demo.mp4
```

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
