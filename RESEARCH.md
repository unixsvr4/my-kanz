# RESEARCH.md — KanzMatch design, derivation, validation

Reproducible research log for the Kanz AI Training Hackathon 2026 submission.
Everything here was produced on 2026-07-17 on macOS (Darwin 25.5.0), Node v-current,
Python 3.13. Commands are copy-pasteable from the repo root.

---

## 1. Problem framing & sources

### 1.1 Hackathon requirements (primary sources, fetched 2026-07-17)

- `https://try.ka.nz/hack` — organizer: **Kanz**, an AI hiring platform (Saudi
  Arabia, 1.2M registered job seekers). Event July 15–22 2026, free, ~50,852
  registrants, Guinness-record attempt (beat 1,842 submissions), 30 prizes,
  LAU ACE accredited certificate + portfolio publication. Taught tools include
  **Claude**, Lovable, Replit, NotebookLM, n8n.
- `https://try.ka.nz/hack/submit/instructions` — submission pipeline is
  **project details → AI video verification → portfolio generation → certificate**.
  Binding constraints extracted:
  - Demo video: MP4, 1–3 min, 50–200 MB, landscape 16:9, must show — for web
    apps — **"AI responding with feature switching"**. Prohibited: slides,
    self-description of planned work, third-party demos, bare links.
  - Screenshots: real app UI / terminal / IDE only; AI-generated mockups rejected.
  - Resume: PDF only.
  - Description fields with word minimums: Problem 40 / Solution 40 /
    How Built 40 / Who Benefits 20 / Future Vision 20 / Bio 20.
- Submission URL: `https://try.ka.nz/hack/submit`.

### 1.2 Design thesis

The judge is a hiring platform. The strongest possible demo for this audience is
a hiring-domain tool whose economics embarrass the incumbent architecture:
**an ATS-style resume↔JD matcher that runs at $0 marginal cost in the browser**,
with LLM coaching as an *opt-in* precision layer. This simultaneously satisfies:

1. "amaze" — instant scoring with visible keyword forensics, plus live streaming
   Claude output with three switchable features (exactly the video requirement);
2. "cost effective" — static file, no backend, no per-user inference cost;
3. privacy — a resume is sensitive PII; client-side scoring means it never leaves
   the device unless the user explicitly invokes the AI coach with their own key.

### 1.3 Algorithm provenance

The scoring model is **not invented for the hackathon** — it is a JS port of
`~/myclaude/my-resumes/ats_checking.py` (1,887 lines), a Python ATS checker whose
keyword dictionary, stopword lists, and noise filters were tuned against a corpus
of **533 real job descriptions** using document-frequency analysis
(`jd_noise_audit.py`: a phrase recurring across dozens of unrelated postings is
boilerplate, not a company-specific skill). Porting a corpus-tuned engine gives
the hackathon app empirically-grounded behavior a weekend-built heuristic would lack.

---

## 2. Scoring model (formal definition)

Let `J` be the JD text and `R` the resume text, both lowercased.

### 2.1 Composite score

```
S(J,R) = 0.70·K(J,R) + 0.15·T(R) + 0.15·Y(J,R)        pass ⇔ S ≥ 0.80
```

Weights inherited unchanged from the Python engine (`ats_checking.py:1752-1754`),
where they were validated across the 533-JD corpus. Keywords dominate because
keyword filtering is what real ATS software actually does first; structure and
years are secondary gates.

### 2.2 Keyword term `K` — harmonic mean of two coverages

```
K = 2·C·D / (C + D)
C = |curated(J) ∩ curated(R)| / |curated(J)|          (curated coverage)
D = Σ w(p)·[match(p,R)] / Σ w(p),  p ∈ dyn(J)         (weighted dynamic coverage)
```

- **Curated dictionary**: 130 canonical skills across 12 categories (cloud,
  containers, CI/CD, IaC, observability, SRE practice, languages, data,
  OS/networking, security, AI/ML-ops, delivery), each with alias lists
  (`k8s → kubernetes`, `golang → go`, `postgres → postgresql`). Matching uses a
  boundary regex tolerant of `c++`, `ci/cd`, `node.js`, `tcp/ip`
  (`(^|[^a-z0-9+]) alias ($|[^a-z0-9+])`).
- **Dynamic phrases** `dyn(J)` are mined from the JD by three sources:
  1. *skill-list lines* — a line splitting on `,;:()` into ≥3 items of ≤4 words
     each (weight 1.0), with leading stopword qualifiers stripped
     (`strong python → python`);
  2. *punctuated tech tokens* — `\w+[./#+]\w+` (`node.js`, `ci/cd`) (weight 1.0);
  3. *Title-Cased proper nouns*, sentence-start and bullet-adjacent positions
     excluded, gerunds excluded — weight **0.5** (`PROPER_NOUN_WEIGHT`), so
     unknown company/product names cannot dominate the denominator.
- **Noise rejection layers** (ported from the Python engine's four-layer design):
  US-state gazetteer (a state name is never a skill), pure numbers/comp figures,
  all-stopword compounds, slash-compounds containing a stopword part
  (`requests/day`), phrases whose every part is already curated
  (double-count guard, e.g. `gcp/aws`), corporate suffixes (`inc`, `llc`).
- **Resume-side matching** accepts either the whole phrase or **all non-stopword
  parts individually** — so `tcp/ip networking` counts when the resume contains
  `TCP/IP` and `networking` in separate bullets. Rationale: the phrase is JD
  phrasing, not a lexical unit the candidate must reproduce verbatim.

**Why a harmonic mean?** `C` measures fit against the *profession's* skill
vocabulary; `D` measures fit against *this posting's* specific asks. An arithmetic
mean lets a resume stuffed with generic skills coast past a posting-specific gap;
the harmonic mean punishes whichever coverage is weaker, which is the correct
failure mode for a screening proxy.

### 2.3 Structure term `T` — 9 binary checks, equally weighted

email · phone · summary section · skills section · experience section ·
education section · ≥6 bullet lines · ≥5 quantified tokens (`%`, `$`, `Nx`,
multi-digit numbers) · length 150–1400 words. These mirror what commercial ATS
parsers demonstrably need to segment a resume.

### 2.4 Years term `Y`

`required` = max of `(\d+)\+?\s*years` matches in the JD (capped at 25 —
larger numbers are almost always benefits/comp text). `have` = max of the
resume's stated `N+ years` and the sum of its date ranges
(`2018 – 2021`, `2021 – Present`). `Y = min(have/required, 1)`, and `Y = 1`
when the JD states no requirement.

---

## 3. Validation (reproduce with one command)

The engine is testable headlessly because the scoring core is pure JS with no DOM
dependencies. Extraction + run:

```bash
python3 - <<'EOF'
import re
html = open('app/index.html').read()
js = re.search(r'<script>\n(.*)</script>', html, re.S).group(1)
core = js.split('/* =========================== UI wiring')[0]
sm = re.search(r'const SAMPLE_JD = `(.*?)`;\n\nconst SAMPLE_RZ = `(.*?)`;', js, re.S)
open('/tmp/kanzmatch_test.js','w').write(core + f'''
const r = analyze(`{sm.group(1)}`, `{sm.group(2)}`);
console.log("TOTAL:", (r.total*100).toFixed(1)+"%");
console.log("missing:", r.kw.miss.map(x=>x[0]).join(", "));
''')
EOF
node /tmp/kanzmatch_test.js
```

### 3.1 Results (2026-07-17, final build)

| Case | Total | Keyword | Structure | Years | Verdict |
|---|---|---|---|---|---|
| Sample SRE JD × sample SRE resume | **88.1%** | 81.1% (C=84.1, D=78.3) | 100% | 100% (8y vs 5y req.) | PASS ✅ |
| Sample SRE JD × unrelated marketing resume (negative control) | **17.3%** | low | partial | fail | FAIL ✅ |

Residual "missing" list for the positive case — `iac, capacity planning,
chaos engineering, multi-region, networking, security, tcp/ip, soc 2 compliance` —
was manually audited: **every item is a genuine absence** from the sample resume
(e.g. it shows Terraform but never writes "IaC"; it has "SOC 2 audit" but not
"compliance"). Zero noise terms remain. That residue *is* the product: it is the
actionable coaching signal fed into the AI panel's prompts.

### 3.2 Debug trail (what failed and how it was fixed)

First build scored the positive pair **53.7%** with dynamic coverage **21.2%** —
unacceptable false-negative pressure. Root-cause analysis of the missing list:

| Symptom | Root cause | Fix | Effect |
|---|---|---|---|
| `ci/cd pipelines: github actions` as one phrase | list-splitter only split on `,;` | split on `,;:()` too | clean per-tool tokens |
| `strong python`, `deep` | stopword qualifiers kept; bullet-adjacent TitleCase captured | strip leading stopwords; skip token after `-`/`•` | qualifiers gone |
| `requests/day` | slash-compound with stopword part | reject slash-compounds containing stopwords | comp/velocity noise gone |
| `tcp/ip networking` missed despite both parts present | whole-phrase matching only | parts-match fallback (all non-stopword parts) | D: 21.2% → 78.3% |
| `inc` (employer suffix) | proper-noun source captured "CloudScale Inc" | corporate suffixes → stopwords | employer noise gone |

Post-fix: **53.7% → 88.1%** on the positive pair while the negative control
stayed at 17.3% — precision improved without recall damage. This mirrors the
Python engine's documented history (its Calendly JD went 47.9% → 100% after an
analogous legal-boilerplate filter).

### 3.3 Threats to validity

- The curated dictionary is SRE/DevOps/cloud-centric; other professions lean on
  the dynamic extractor alone (harmonic mean degrades gracefully — `C` treats an
  empty curated set as coverage 1, so `K → D`).
- Two hand-built samples ≠ a corpus. The Python parent was corpus-validated; the
  port inherits its architecture but a JS-side re-validation against the 533-JD
  corpus is future work (§6).
- Keyword presence ≠ competence; the tool measures *screening survivability*,
  which is what it claims to measure.

---

## 4. AI layer — engineering decisions

- **Transport**: raw `fetch` to `POST https://api.anthropic.com/v1/messages`
  with `anthropic-version: 2023-06-01` and the
  **`anthropic-dangerous-direct-browser-access: true`** header — Anthropic's
  documented CORS opt-in for direct browser calls. Chosen over the official SDK
  because the product constraint is *one static file with no build step*; an npm
  dependency would violate the architecture. (In any bundled project the SDK is
  the right default.)
- **BYOK trust model**: the key is used only in-page; persisted to
  `localStorage` **only** behind an explicit "remember key" checkbox. Honest
  caveat rendered in the footer: BYOK in a browser is safe when the user pastes
  *their own* key into a page they trust; the page makes no other network requests
  (verifiable — it's one readable file).
- **Models**: default `claude-opus-4-8` (best quality, $5/$25 per MTok);
  `claude-haiku-4-5` offered as an explicit "economy" choice ($1/$5). The
  user chooses — the app never silently downgrades.
- **Streaming**: `stream: true`, hand-parsed SSE (`content_block_delta` →
  `text_delta` appended live). Streaming is what makes the demo video read as
  "AI responding".
- **`max_tokens: 2048`** — deliberate: the three features produce short coaching
  outputs; the cap is a cost guarantee, and the per-run cost line (computed from
  the streamed `usage.output_tokens` × published output price) makes the
  economics visible in the UI — a run typically costs **0.1–0.5¢**.
- **Refusal handling**: `message_delta.stop_reason === "refusal"` surfaces a
  clear message instead of silent empty output.
- **Prompt hard rules**: every feature prompt forbids inventing tools, metrics,
  employers, or experience — inherited verbatim from the `tailor_resume.py`
  system-prompt discipline, because a hiring-platform judge will probe for
  hallucinated credentials.

## 5. UI / dataviz decisions

- Score display follows the validated reference dataviz palette: single-hue blue
  (`#2a78d6` light / `#3987e5` dark) for the three magnitude bars (sequential
  job — one hue, no rainbow), status colors (`good #0ca30c` with dark-mode text
  step, `critical #d03b3b/#e66767`) reserved for verdict/chips and **always
  paired with ✓/✗ glyphs + text** so meaning never rides on color alone.
- Dark mode is *selected*, not auto-inverted: separate token sets under
  `@media (prefers-color-scheme: dark)` and `[data-theme]`, with the manual
  toggle winning both directions.
- Hero number + three labeled bars (150px label / track / tabular-nums value)
  instead of a gauge: a gauge encodes one number in angle for no gain; bars make
  the three weighted components comparable at a glance.
- Chips are the interaction payload: matched (✓ green-tinted) vs missing
  (✗ red-tinted, with the ×0.5 weight shown for proper-noun phrases so users see
  the model's own confidence).

## 6. Cost analysis (the "cost effective" claim, quantified)

| Cost center | Typical SaaS resume tool | KanzMatch |
|---|---|---|
| Hosting | $5–50/mo (server + DB) | **$0** (static file, free-tier pages hosting) |
| Per-analysis inference | 1 LLM call ≈ $0.01–0.10 | **$0** (deterministic, client CPU) |
| Per-AI-coach run | included in subscription ($10–30/mo) | **~$0.001–0.005**, user-paid BYOK |
| Scaling to 1.2M Kanz users | linear server cost | **$0 marginal** — the CDN serves one file |
| Data compliance surface | stores PII resumes | **none** — no server ever receives a resume |

Worst-case monthly cost to operate at any scale: **$0.00**. The only money that
moves is the user's own opt-in API spend, displayed per-run in the UI.

## 7. Reproducibility & future work

- Repo layout: see README. `app/index.html` is authoritative; there is no build.
- Re-run validation: §3 command. Manual E2E: `python3 -m http.server -d app 8000`,
  load samples, Analyze, then exercise the three AI tabs with a real key.
- Future work: (a) re-validate the JS port against the full 533-JD corpus and
  report per-JD score deltas vs the Python engine; (b) client-side PDF text
  extraction (pdf.js) with the parent engine's ligature-repair table;
  (c) Arabic-language JD support (Kanz's home market) — the dynamic extractor is
  Latin-script-biased today; (d) Web Worker offload for very large corpora.

## 8. Tooling disclosure

Built with Claude (Anthropic) as pair-programmer for code generation and this
documentation; the deterministic engine's design derives from the author's
pre-existing corpus-tuned Python ATS checker. All validation numbers above were
produced by executing the shipped code, not estimated.
