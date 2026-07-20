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

### 2.2 Keyword term `K` — confidence-ramped harmonic mean of two coverages

```
H = 2·C·D / (C + D)
C = |curated(J) ∩ curated(R)| / |curated(J)|          (curated coverage)
D = Σ w(p)·[match(p,R)] / Σ w(p),  p ∈ dyn(J)         (weighted dynamic coverage)
conf = min(1, Σ w(p) / DYN_RELIABLE_N)                (N = 4.0)
K = conf·H + (1 − conf)·C
```

The `conf` ramp is ported from the Python engine's fix for the "all-curated JD
scores 30%" bug: a JD whose skills are all curated leaves the dynamic miner
1–2 (often junk) phrases, and a single unmatched one drove the plain harmonic
mean — and the whole keyword score — to ~0. Below `DYN_RELIABLE_N` weighted
phrases the dynamic signal blends back toward the curated score.

- **Curated dictionary**: 144 canonical skills across 12 categories (cloud,
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
- **JD boilerplate excision** (`prepJD`, ported from the Python engine where it
  was validated on a 563-JD corpus). The dynamic score is `matched/extracted`,
  so every boilerplate phrase that survives extraction and isn't in the resume
  silently tanks a genuinely strong match. Every rule is **closed-set or
  structural** — it matches a boilerplate *family* by shape, never per-company
  vocabulary, so it holds for technical and non-technical JDs alike:
  1. labeled company-intro blocks ("The Company:", "About Us", "Our Mission")
     excised up to the next job-content header — the required boundary means it
     can never nuke a whole posting;
  2. trailing legal/eligibility boilerplate truncated at the earliest marker
     (EEO employer statements, "authorized to work", visa sponsorship, CCPA
     "Notice at Collection", background checks, recruitment-fraud disclaimers);
  3. tail sections (benefits/perks/pay/hiring process/shift) skipped from a
     colon-tolerant header set ("The Perks:" — an EOL-anchored regex silently
     misses colon-suffixed headers) until a *real* job-content header — resuming
     on any TitleCase line wrongly reopened the cut on perk items like "Casual
     Dress";
  4. anchored-block strippers: a run of list-like lines with ≥2 closed-set
     benefit anchors (401k/insurance/PTO) is a perk list, and a run of bare
     phrases with ≥2 soft-skill anchors (Influence, Business Acumen) is an HR
     competency taxonomy — drop the whole run, so unbounded items (benefit
     product names, "Solution Delivery Process") die without enumeration;
  5. "At \<Company\>, we…" pitch lines and posting-metadata lines
     ("LOCATION: New York/ New Jersey", "REPORTS TO: …") dropped;
  5b. HEADERLESS pitch caught by grammar alone (the SentiLink case: investor/
     press/office paragraphs sit under the "About the job" chrome with no
     header any block excision could anchor on) — lines opening with
     We/We're/We've/Our (first-person-plural corporate narrative; requirement
     bullets never open that way) or "\<Brand\> provides/builds/is backed/was
     founded/has earned…" (the corporate-verb whitelist protects requirement
     lines that open with a brand, e.g. "Google Cloud Platform experience
     required");
  6. missing-space sentence welds repaired (`best.Here` → `best. Here`) so they
     can't fake dotted tech tokens;
  7. the employer's own name — captured with zero configuration from its EEO
     self-reference, corporate self-intro ("X is a global company…"), or "At X,
     we…" pitch — is never counted as a skill.
- **Phrase-level noise rejection**: gazetteers (US states, countries, world
  cities, calendar and time-zone words, compass directions, spelled-out
  numbers — never skills in any
  profession), HR-taxonomy soft skills ("stakeholder management", "growth
  mindset" — every candidate claims them, scoring them is meaningless),
  job-title words (senior/engineer/manager), pure numbers/comp figures,
  hyphenated descriptive adjectives (`rock-solid`, `people-centered`,
  `drag-and-drop`), office-address fragments, phrases containing any stopword
  part (prose fragments — the real skill inside is caught by the curated pass),
  double-count guards (every part curated e.g. `gcp/aws`; curated term + generic
  filler e.g. `agile practices`; slash-fragments of curated compounds e.g. bare
  `ci` from `ci/cd`), and TitleCase phrases are never welded across punctuation
  ("SRE Discipline: Strong…" can't become "discipline strong").
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
| Sample SRE JD × **same resume as a PDF** (cupsfilter-generated, parsed by the app's pdf.js path in Node with `pdfjs-dist@3.11.174`) | **88.1%** | 82.9% | 100% | 100% | PASS ✅ — PDF path ≡ text path |
| Sample SRE JD × **same resume as a .docx** (python-docx-generated with `List Bullet` styles + entity edge cases, parsed by the app's built-in ZIP/OOXML extractor in Node) | **88.1%** | — | 100% (10 bullet lines reconstructed) | 100% | PASS ✅ — DOCX path ≡ text path |
| **Arabic** SRE JD × **Arabic** SRE resume, mixed Arabic grammar + Latin tool names (2026-07-20, added with the bilingual feature — §4.3) | **94.5%** | 94.5% (C=94.1, D=100) | 88.9% | 100% (5y vs 9y) | PASS ✅ |
| **Arabic** SRE JD × **Arabic** unrelated marketing resume (negative control) | **26.7%** | 0% | partial | n/a | FAIL ✅ |

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

### 4.1 PDF upload (added 2026-07-17)

Both panes accept `.pdf`. Design decisions:

- **Parser**: Mozilla **pdf.js 3.11.174** (Apache-2.0) rather than a hand-rolled
  extractor — resume PDFs from Google Docs/Word routinely use `Identity-H`
  encodings with `ToUnicode` CMaps that a minimal parser garbles, and demo-day
  reliability beats purity. The 3.x line is used because it exposes a classic
  `<script>` global (`pdfjsLib`); 4.x is ESM-only and would force a build step.
- **Vendored, offline-first** (added same day): `app/vendor/pdf.min.js` +
  `pdf.worker.min.js` are committed to the repo, so PDF parsing needs no
  network at all. Supply-chain provenance: the vendored files' SHA-256 hashes
  were verified **identical** to the official `pdfjs-dist@3.11.174` npm
  package's `build/` files
  (`pdf.min.js` = `5b5799e6…1566946`, `pdf.worker.min.js` = `feabdf30…bb8527b`).
  `loadPdfJs()` is still lazy (script injected on first `.pdf` selection,
  memoized promise) and falls back to the cdnjs CDN only if the vendored copy
  is missing — e.g. someone deployed `index.html` alone. Parsing is 100%
  client-side either way — the PDF bytes never leave the browser.
- **Line reconstruction**: pdf.js returns positioned glyph runs, not lines.
  Lines are rebuilt by emitting `\n` when the baseline (`transform[5]`) moves
  by >2pt or the item carries `hasEOL` — this preserves bullets and section
  headings, which the structure checks (≥6 bullet lines) depend on.
- **Ligature repair**: extracted text is `normalize("NFKC")`-folded (ﬁ→fi,
  ﬂ→fl …), mirroring `ats_checking.py`'s `_repair_ligatures` so PDF typography
  can't silently break keyword matches like "profile"/"certified".
- **Verified** (see §3.1 last row): the sample resume rendered to a real PDF via
  `cupsfilter`, parsed with the same code in Node, scores **88.1%** — byte-path
  parity with the plain-text run, zero structure-check regressions. Scanned
  (image-only) PDFs yield no text and produce an explicit error, not a silent 0%.
  The **vendored bytes themselves** were additionally exercised: requiring
  `app/vendor/pdf.min.js` in Node (worker pointed at the vendored
  `pdf.worker.min.js`) extracts the full 190 words with all sentinel tokens
  intact, and a local `http.server` serve returns both files at the exact
  relative URLs the loader requests (HTTP 200; 320,004 and 1,087,212 bytes).

### 4.2 Word .docx upload (added 2026-07-17, for Windows/Word users)

Both panes accept `.docx`, parsed by a **built-in zero-dependency extractor** —
no library, no network, no storage; the file bytes never leave the browser.

- **Why hand-rolled here but pdf.js for PDF**: a `.docx` is just a ZIP whose
  `word/document.xml` holds the text in one well-specified XML schema (OOXML),
  so a complete extractor is ~70 lines; PDF text extraction, by contrast,
  requires font/CMap machinery that justifies a real library.
- **ZIP layer**: the extractor scans back for the End-Of-Central-Directory
  record (sig `0x06054b50`, tolerating trailing comments), walks the central
  directory to find `word/document.xml`, re-reads name/extra lengths from the
  *local* header (they may legally differ), and inflates method-8 entries with
  the **browser-native `DecompressionStream("deflate-raw")`** (Chrome 103+/
  Safari 16.4+/Firefox 113+ — universal by 2026). Method-0 (stored) supported;
  anything else errors explicitly.
- **OOXML layer**: paragraphs (`<w:p>`) become lines; runs concatenate `<w:t>`
  text with `<w:tab/>`→space and `<w:br/>`→newline; XML entities (named +
  numeric) are decoded. **List items become `- ` bullets** when the paragraph
  carries either direct numbering (`<w:numPr>`, Word-UI bullets) *or* a
  `List*` paragraph style (`<w:pStyle w:val="ListBullet"/>` — how python-docx
  and many templates encode bullets) — critical because the structure score
  counts bullet lines. Regex over the XML is safe here because OOXML emitted
  by Word/python-docx is machine-generated and canonical; no DOMParser needed,
  which also lets the identical code run in the Node validation harness.
- **Legacy `.doc` detection**: the OLE container signature (`0xD0CF11E0`) is
  recognized and rejected with an actionable message ("in Word use File →
  Save As → .docx") instead of a confusing ZIP error.
- **Verified** (§3.1 last row): the sample resume regenerated as a real
  `.docx` via python-docx with `List Bullet` styles plus an entity-torture
  bullet (`R&D: cost < $500k & uptime > 99.9% — “quoted”`) round-trips
  perfectly — 10 bullet lines reconstructed, all sentinel tokens and decoded
  entities intact, **88.1%** score parity with the plain-text path, and the
  legacy-.doc negative control produces the save-as tip.

### 4.3 Bilingual UI + Arabic-aware scoring engine (added 2026-07-20)

Requested explicitly for Kanz's home market (Saudi Arabia): a 🌐 toggle switches
the whole UI between English and Arabic with a genuine `dir="rtl"` layout, and —
the harder half — the scoring engine itself understands Arabic JDs/resumes rather
than just relabeling English-only logic.

**UI layer.** Every static string routes through a `data-i18n`/`data-i18n-ph`/
`data-i18n-title` attribute scan and an `I18N.{en,ar}` dictionary; dynamic
render paths (`structureScore`'s checks, `yearsScore`'s sentences, upload/AI
error strings) were refactored to return **translation keys**, not baked-in
English literals, so a language switch after results are already on screen
re-renders instead of requiring a re-analyze (`renderResults()` is idempotent
and reused by both the Analyze click and `applyI18n()`). RTL is `dir="rtl"` on
`<html>` — CSS Grid/Flexbox mirror automatically under `dir`; the only manual
fixes were a hardcoded `text-align:right` → logical `text-align:end`, an
Arabic-capable font fallback (`"Noto Sans Arabic", "Geeza Pro", Tahoma`), and
`unicode-bidi:plaintext` on chips/values so embedded Latin tech terms (`aws`,
`kubernetes`) don't get bidi-reordered inside Arabic sentences. Both textareas
get `dir="auto"` so pasted JD/resume text direction is detected per-field,
independent of the current UI language.

**Engine layer — what actually had to change, and what didn't:**

- **Digit normalization**: `normalizeDigits()` maps Arabic-Indic numerals
  (٠–٩) to Western digits once, in `analyze()`, before any `\d` regex runs —
  a no-op on English text, and it makes every existing years/quantified-
  achievement regex work unmodified on `٥+ سنوات` the same as `5+ years`.
- **Word-boundary matching is script-aware.** The original `boundaryRe()`
  boundary class `[^a-z0-9+]` treats *every* Arabic letter as "already a
  boundary" (Arabic isn't in `a-z0-9`), which would let a short Arabic alias
  false-match as a substring of a longer, unrelated word. Arabic aliases now
  get a dedicated boundary class requiring the neighbor be neither a Latin
  alphanumeric nor an **Arabic letter**. First attempt used the full Arabic
  Unicode block (`؀-ۿ`) for that class and broke on the very first real test —
  Arabic punctuation (، ؛) lives inside that same block, so a word followed by
  an Arabic comma was wrongly treated as still mid-word. Fixed by narrowing the
  boundary class to `ء-ي` (letters only), leaving Arabic punctuation
  and digits as valid boundaries, exactly like English `,`/`.` are.
- **The definite article "ال" attaches with no space** ("موثوقية" vs
  "الموثوقية" — reliability / *the* reliability), so a single hand-written
  Arabic alias can miss its own article-bearing or article-free form on the
  other side of the JD/resume pair. Rather than hand-authoring both spellings
  for every alias, `ALIAS_INDEX` construction auto-derives the alternate form
  for any alias containing Arabic characters. This alone fixed two false
  negatives (`reliability`, `monitoring`) in the validation fixture (§3.1).
- **Curated Arabic aliases were added selectively, not exhaustively**: practice/
  domain vocabulary (`المراقبة` monitoring, `الأتمتة` automation, `الشبكات`
  networking, `الأمن السيبراني` cybersecurity, `الامتثال` compliance,
  `الذكاء الاصطناعي` AI, `التوثيق` documentation, `الترحيل` migration, ~25 terms
  total) got real Arabic aliases; tool/product names (Kubernetes, Terraform,
  AWS, Python) were deliberately left Latin-only, because that mirrors how
  Gulf tech job postings actually code-switch — nobody writes "كوبرنيتيس" for
  Kubernetes in a real posting.
- **Structure-check section headers** (`structureScore`) now alternate English
  and Arabic patterns in the same regex (`/summary|profile|ملخص|نبذة/`, etc.)
  rather than branching on detected language — simpler, and harmless for
  English text since it never contains the Arabic alternatives.
- **`prepJD`'s boilerplate stripper** gained a *small*, additive set of common
  Arabic section headers (`عن الشركة`, `المسؤوليات`, `المتطلبات`, `المزايا`)
  in the existing `INTRO_HEADINGS`/`JOB_CONTENT`/`TAIL_HEADINGS` alternations.
  This is **not** claimed to be corpus-validated the way the English stripper
  is (§2.2 was tuned against 533 real JDs); it is a reasonable first pass,
  documented here as a known limitation rather than overclaimed.
- **Deliberately out of scope**: no Arabic proper-noun mining (source 3 of
  `extractDynamicPhrases` relies on Title-Case, which doesn't exist in
  Arabic — sources 1 and 2, skill-list-line splitting and punctuated tokens,
  already work in Arabic and carried the dynamic signal in testing); no
  Arabic month-name date-range parsing (only the ISO-ish `YYYY–YYYY`/
  `YYYY–حتى الآن` form is handled); no Saudi-city gazetteer parity with the
  English `US_STATES` noise filter. None of these caused a validation failure
  in testing, but a larger real-world Arabic JD corpus could expose gaps here
  the same way the original English engine needed corpus tuning (§2.2).

**Verified** (§3.1, added 2026-07-20): a synthetic Arabic SRE JD × Arabic SRE
resume (mixed Arabic grammar with Latin tool names, matching real posting
style) scores **94.5%** with correct structure detection of Arabic section
headers (`نبذة`, `المهارات`, `الخبرة`, `التعليم`) and correct Arabic years-of-
experience parsing (`٥+ سنوات` → required 5); the one residual "missing" item
(`cloud computing`) is genuine — the resume never restates it. An Arabic
negative control (same JD × an unrelated Arabic marketing resume) scores
**26.7%** with **zero** false-positive keyword matches, confirming the
bilingual engine discriminates correctly in both directions, not just on the
positive case. The pre-existing English validation (§3.1 row 1) was re-run
after every engine change in this section and stayed byte-identical, confirming
zero regression to English scoring.

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
  report per-JD score deltas vs the Python engine; (b) ~~client-side PDF text
  extraction~~ — **shipped** (§4.1); next step is OCR fallback for scanned PDFs;
  (c) ~~Arabic-language JD support (Kanz's home market)~~ — **shipped** (§4.3,
  bilingual UI + Arabic-aware scoring engine); next step is corpus-validating
  the Arabic boilerplate stripper and Saudi-city gazetteer the way §2.2 was
  validated for English; (d) Web Worker offload for very large corpora;
  (e) ~~vendor `pdf.min.js` for fully-offline PDF parsing~~ — **shipped**
  (§4.1, `app/vendor/`, hash-verified against the official npm package).

## 8. Tooling disclosure

Built with Claude (Anthropic) as pair-programmer for code generation and this
documentation; the deterministic engine's design derives from the author's
pre-existing corpus-tuned Python ATS checker. All validation numbers above were
produced by executing the shipped code, not estimated.
