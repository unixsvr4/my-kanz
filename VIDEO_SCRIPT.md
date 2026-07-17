# VIDEO_SCRIPT.md — 2-minute demo (Kanz submission rules compliant)

**Format targets**: MP4 · landscape 16:9 · 1–3 min (this script ≈ 2:00) · 50–200 MB.
**Rule satisfied**: web apps must show *"AI responding with feature switching"* —
scenes 4–6 are exactly that. **Nothing prohibited**: no slides, no "I plan to…",
no third-party demos, no bare links.

## Recording setup (macOS)

```bash
python3 -m http.server -d app 8000     # serve the app at http://localhost:8000
# Record: QuickTime → File → New Screen Recording, 16:9 browser window, mic on.
# Keep the browser at 100% zoom; hide bookmarks bar; use a clean profile.
# If the file exceeds 200 MB: ffmpeg -i raw.mov -vcodec h264 -crf 23 demo.mp4
```

Have ready before recording: samples load with one click (built-in); your
Anthropic API key on the clipboard.

## Script

| # | Time | On screen | Say (voiceover) |
|---|---|---|---|
| 1 | 0:00–0:15 | App open in browser, cursor idle | "This is KanzMatch — a resume-to-job-description analyzer that runs entirely in your browser. One file, no server, no signup, and your resume never leaves your device." |
| 2 | 0:15–0:35 | Click **Load sample JD**, **Load sample resume**, then **Analyze match**. Bars animate, 88% appears | "Paste any job posting and your resume, hit Analyze. Scoring is instant and free — a corpus-tuned engine rates keyword coverage, resume structure, and years of experience, weighted like a real applicant-tracking system." |
| 3 | 0:35–0:55 | Scroll to chips; hover matched, then missing | "Here's the forensic part: exactly which skills matched, and which the posting asks for that your resume never says — like 'IaC' or 'SOC 2 compliance'. That's your honest edit list, not guesswork." |
| 4 | 0:55–1:20 | Paste API key. Tab **✍️ Rewrite my summary** → **Run AI feature**. Text streams live | "Now the AI coach — powered by Claude with your own API key. Feature one: rewrite my summary. Watch it respond live — it's rewriting the summary using the job's own vocabulary, and it's hard-ruled to never invent experience." |
| 5 | 1:20–1:40 | Switch tab to **🧭 Gap-closing plan** → Run. New stream | "Switch features: a thirty-day gap-closing plan. For each real gap the scanner found, Claude tells me the fastest credible way to close it and the resume bullet I could honestly write afterward." |
| 6 | 1:40–1:52 | Switch tab to **✉️ Cover-letter opener** → Run. Point at the cost line under the output | "Third feature: a cover-letter opener grounded only in facts from my resume. And notice the cost line — this run used a few hundred tokens: a fraction of one cent." |
| 7 | 1:52–2:00 | Click theme toggle (dark mode), rest on score screen | "Zero hosting cost, zero data collection, AI only when you want it. That's KanzMatch." |

## Why this passes AI video verification

- The app is **actively producing output** on camera (scores computed, three
  distinct AI features streaming) — the core thing the verifier checks.
- "Feature switching" is literal: three tabs, three different AI behaviors, run
  back-to-back in one take.
- Every frame is the real running app or its live output; no mockups.
