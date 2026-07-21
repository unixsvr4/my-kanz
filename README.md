# KanzMatch — AI Resume ↔ Job Match Analyzer

**Kanz AI Training Hackathon 2026 submission** (https://try.ka.nz/hack · July 15–22, 2026).

A single-file, zero-cost web app that scores any resume against any job description
**entirely in the browser** — no server, no signup, no data leaving the device — and
then (optionally) coaches the candidate with Claude via a bring-your-own-key AI panel
with three switchable features. Fully bilingual: **English and Arabic, with a real
RTL layout** (not just mirrored CSS — the scoring engine itself understands Arabic
JDs and resumes; see §4.3 in RESEARCH.md).

```
my-kanz/
├── app/
│   ├── index.html            ← the entire product (HTML + CSS + JS, ~1500 lines)
│   └── vendor/               ← pdf.js 3.11.174 (Mozilla, Apache-2.0), vendored for
│       ├── pdf.min.js           fully-offline PDF parsing; hashes verified against
│       └── pdf.worker.min.js    the official pdfjs-dist npm package
├── README.md         ← this file
├── RESEARCH.md       ← methodology, algorithm derivation, validation, cost analysis
├── SUBMISSION.md     ← hackathon submission package (all required fields, word-counted)
└── VIDEO_SCRIPT.md   ← 1–3 min demo-video script matching the submission rules
```

## Run it

No build, no install:

```bash
open app/index.html            # macOS — double-click works too
# or serve it (identical behavior):
python3 -m http.server -d app 8000   # → http://localhost:8000
# then, when done, stop it (or the next run fails with "Address already in use"):
#   Ctrl-C if it's in the foreground, or:
screenshots/scripts/99_stop_server.sh    # kills whatever's on port 8000, safe to re-run
```

Deploy for $0: push the `app/` folder to GitHub Pages, Cloudflare Pages, Netlify, or
an S3 bucket. **Everything except the opt-in AI coach works fully offline** —
scoring is pure client-side JS and PDF parsing uses the vendored pdf.js (with a
CDN fallback if `vendor/` wasn't deployed). The only network call the app can ever
make besides that fallback is api.anthropic.com when the user runs the BYOK coach.

## What it does

0. **🌐 language toggle (top-right)** switches the entire UI between English and
   Arabic — every label, button, hint, error message and the AI coach's tab
   names — and flips the page to a true `dir="rtl"` layout (score card, chip
   grids, structure/experience cards all mirror correctly; English tech terms
   inside Arabic text still render left-to-right). It isn't cosmetic-only: the
   scoring engine is Arabic-aware — a JD or resume written in Arabic is scored
   with Arabic section-header detection, Arabic years-of-experience phrasing,
   Arabic-Indic digit normalization, and curated Arabic aliases for common
   practice/domain terms (tool and product names stay in Latin script, matching
   real Gulf tech-hiring code-switching conventions). See RESEARCH.md §4.3.
1. **Paste a job description + your resume** (or press the two *Load sample*
   buttons). Both panes also accept **.txt/.md/.pdf/.docx uploads**, all parsed
   client-side and fully offline: PDFs via the vendored pdf.js (lazy-loaded from
   `vendor/` only at that moment), Word .docx via a built-in zero-dependency
   parser (native `DecompressionStream` + OOXML paragraph reconstruction).
   File bytes never leave the browser and are never stored.
2. **Analyze match** → instant deterministic ATS-style score:
   - **Keywords 70%** — confidence-ramped harmonic mean of (a) coverage of a
     curated 181-term SRE/DevOps/cloud skill dictionary with aliases
     (`k8s`→kubernetes, `golang`→go, …) and (b) coverage of phrases mined
     dynamically from *this* JD (skill-list lines, punctuated tech tokens like
     `node.js`/`ci/cd`, Title-Cased proper nouns down-weighted ×0.5); below 4
     weighted dynamic phrases the dynamic signal blends back toward the
     curated score, so a tiny noisy sample can't zero out a strong curated
     match. Before mining, JD
     boilerplate is excised by closed-set/structural rules ported from the
     673-JD-validated Python engine — company-intro blocks, perk lists, HR
     competency taxonomies, legal/EEO/visa/fraud tails, "At \<Co\>, we…"
     pitch, HEADERLESS pitch caught by grammar alone (lines opening
     "We're/We've/Our…" or "\<Brand\> provides/is backed/was founded…"),
     posting metadata, countries/continents/time-zones (incl. weekday/month
     abbreviations and hybrid-schedule anchor days like "Mon/Tue/Wed"), and
     the employer's own name — so benefits and marketing words never tank the
     score, for technical **and** non-technical JDs alike (see RESEARCH.md
     §2.2).
   - **Structure 15%** — 9 checks: contact info, sections, bullets, quantified
     achievements, length.
   - **Experience 15%** — years required (JD regex) vs years shown (stated
     `N+ years` or summed date ranges, `2018–Present` aware).
   - Pass bar: **80%**, matching common ATS screening thresholds.
3. **Matched / missing keyword chips** show exactly what to (honestly) add.
4. **AI coach (optional, BYOK)** — paste your own Anthropic API key and switch
   between three streaming features:
   - ✍️ **Rewrite my summary** — tailors the resume summary to the JD, hard-ruled
     never to invent experience.
   - 🧭 **Gap-closing plan** — a prioritized 30-day plan to close the top 5 real gaps.
   - ✉️ **Cover-letter opener** — grounded only in facts from the resume.

   Each run reports its actual token count and cost (typically **well under 1¢**).

## Why it's cost-effective (the point of the design)

| Layer | Choice | Cost |
|---|---|---|
| Hosting | one static HTML file | $0 (GitHub/Cloudflare Pages free tier) |
| Backend | none — scoring runs client-side | $0 |
| Database | none — nothing is stored server-side | $0 |
| Default inference | deterministic algorithm, not an LLM | $0 |
| AI coach | opt-in, user's own key, streamed, 2K-token cap | ~0.1–0.5¢ per run, paid by the user |

The deterministic core means the app is **useful at zero marginal cost for all
1.2M Kanz job seekers simultaneously** — the LLM is a precision add-on, not a
dependency. Privacy falls out of the same architecture: the resume never touches
a server we operate (there isn't one).

## Provenance

The scoring architecture is a JavaScript port of a ~2,300-line open Python ATS
checker (`ats_checking.py`) that was empirically tuned against a corpus of 673
real job descriptions via document-frequency noise analysis. See **RESEARCH.md**
for the derivation, the validation runs, and every design decision with evidence.
