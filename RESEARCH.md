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
`~/myclaude/my-resumes/ats_checking.py` (2,280 lines), a Python ATS checker whose
keyword dictionary, stopword lists, and noise filters were tuned against a corpus
of **673 real job descriptions** using document-frequency analysis
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
where they were validated across the 673-JD corpus. Keywords dominate because
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

- **Curated dictionary**: 181 canonical skills across 12 categories (cloud,
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
  was validated on a 673-JD corpus). The dynamic score is `matched/extracted`,
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
- **Phrase-level noise rejection**: gazetteers (US states, countries,
  continents/world-regions, world cities, calendar and time-zone words —
  including weekday/month abbreviations and slash-joined anchor-day schedules
  like "Mon/Tue/Wed" — compass directions, spelled-out
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
  port inherits its architecture but a JS-side re-validation against the 673-JD
  corpus is future work (§6).
- Keyword presence ≠ competence; the tool measures *screening survivability*,
  which is what it claims to measure.

### 3.4 2026-07-20 sync: porting the Python engine's 673-JD noise-audit round

The Python parent re-ran its own document-frequency noise audit after its JD
corpus grew past 672 real postings, and this port pulled the resulting fixes
across so the two engines don't drift:

- **Calendar gazetteer completed**: `TIME_WORDS` only matched exact weekday/
  month spellings, missing plurals ("Thursdays" from hybrid-schedule bullets:
  "Tuesdays and Thursdays are our anchor days") and abbreviations ("Aug",
  "Mon/Tue/Wed"). Also fixed a JS-specific gap the Python source doesn't share:
  `phraseOk`'s calendar/compass check only fired for single-token phrases
  (`parts.length === 1`), so a slash-joined compound like `Mon/Tue/Wed` or
  `East/West` — which JS's tokenizer already flattens into multiple `parts` at
  the same step, unlike the Python port's separate whitespace/punctuation
  split — walked straight through. Fixed by checking `parts.every(...)`
  unconditionally instead of gating on phrase length.
- **New `CONTINENTS` gazetteer** (Europe, Asia, APAC, EMEA, Americas…), the
  same one-level-up companion to `COUNTRIES` the Python engine added.
- **`pre-tax` benefits leak** (commuter/FSA/retirement lines) closed in
  `BENEFITS_LINE`.
- **`must-haves`/`nice-to-haves`/`life balance`/`early-stage`/`successful`**
  joined `SOFT_SKILLS` (this port's stand-in for the Python `NOISE_PHRASES`
  set — SOFT_SKILLS is checked against the whole phrase, not just per-word).
- **Curated dictionary grew 145 → 181 canonicals** with a representative
  (not exhaustive — see below) slice of the ~55 real tools the Python audit
  surfaced: ServiceNow, Podman, Docker Swarm, bare-metal, Kyverno, Atlantis,
  Bicep/ARM templates, Sentry, AppDynamics, Grafana Tempo, VictoriaMetrics,
  MTTR/MTTD, Kinesis, ElastiCache, message queue, OpenTSDB, ETL, BGP, Cilium,
  VLAN, Okta, PKI, CIS Benchmarks, SCA, SOAR, XDR, SOX, FISMA, CKS, CSPM,
  GuardDuty, GovCloud, MCP, and RAG.

This was a **deliberate partial port, not full parity**: the Python engine's
332 canonicals include many terms (Slurm/HPC schedulers, Oracle-stack
specifics, several AI-observability niche tools) that don't fit this app's
tighter, bilingual-first, hackathon-scoped dictionary. The noise-reduction
*mechanisms* (gazetteers, benefits/boilerplate stripping, the confidence-ramp
doctrine) were ported in full; the curated *vocabulary* was ported selectively
by relevance to this app's SRE/DevOps/cloud scope. Re-run §3's validation
command after any future sync to confirm the sample-JD score and residual
"missing" list stay sane.

### 3.5 2026-07-21 sync: hyphenated compliance/safety adjectives no longer count as missing skills

A real-world JD (Fabric Health, Senior SRE) exposed a false-negative gap in
`HYPHEN_ADJ`, the closed-set regex that drops descriptive hyphenated
adjectives ("rock-solid", "vm-hosted") from the dynamic-phrase pool so they
aren't scored as missing tool names. Its suffix list didn't yet include
`critical`, `prone`, `compliant`, or `safety`, so JD phrasing like
"HIPAA-compliant architecture", "safety-critical environments", and
"error-prone procedures" — pure prose, not tool names — was flagged as a
missing skill even when the underlying real term (HIPAA) was already matched
via the plain curated-keyword check. The `[a-z]+-` prefix was also too
strict to admit alphanumeric prefixes like `soc2-compliant`, so it's now
`[a-z0-9]+-`. Ported directly from the same-day fix in the Python parent
(`ats_checking.py`'s `_HYPHEN_ADJ_RE`), which found the same gap against its
own 688-JD corpus and confirmed it with a zero-regression full-corpus
regression run (score: 33.9% → 94.2% on the triggering JD, 1 legitimate
FAIL→PASS flip, 0 illegitimate flips). Verified in this port via a
standalone Node smoke test against `HYPHEN_ADJ` (all seven adjective
compounds now rejected; `ci-cd`/`scikit-learn`/`node-js`/`k8s` still pass
through untouched) and an end-to-end `analyze()` run on a synthetic
Fabric-shaped JD/resume pair scoring 90.8%.

Note: the *other* half of the Python fix — a JD "Recruitment Fraud Alert:
Protect Yourself" header leaking its scam-warning block into phrase mining
because the header-matching regex required an exact end-of-line match —
turned out to be a Python-only bug. This port's `LEGAL_MARKERS` already
truncates on an unanchored `recruitment fraud` substring match (§2.2), so a
trailing subtitle after the header never breaks it here; confirmed via the
same Node smoke test with the verbatim triggering JD text (all scam-block
phrases — `fabrichealth.com`, `gem.com`, `google meet`, `sms`, "verify the
domain", "authorized" — stripped correctly, no code change needed).

### 3.6 2026-07-21 sync: prose sentence-starters and a garbled JD line no longer count as missing skills

A real-world JD (Prudential, Senior Cloud Engineer) scored 95.7% curated but
only 1/7 on the dynamic-phrase check, tanking the harmonic-mean keyword score
to 43.9% FAIL. All 6 "missing" phrases in the Python engine turned out to be
noise, not skill gaps:

- **`awareness`, `dna`, `expect`** — generic sentence-starter/header words
  mistaken for proper nouns ("Awareness of cloud platforms...", "built into
  our DNA!", "Here is What You Can Expect..."). Joined `SOFT_SKILLS` (this
  port's `NOISE_PHRASES` stand-in, per §3.4).
- **`shell/power` and its bare fragment `power`** — a garbled JD line
  ("Shell/Power scripting", meaning PowerShell) that double-counts the
  already-curated `shell` (an alias of `bash`) and re-surfaces `power` alone
  once the compound itself is filtered. Also joined `SOFT_SKILLS`.
- **`financial/insurance`** — an industry-vertical descriptor, not a tech
  skill. This one did **not** need porting: this engine's `STOPWORDS` already
  contains `insurance` (a benefits-boilerplate word, added for medical/dental/
  vision-insurance lines), and `phraseOk`'s "any part of a multi-word phrase
  is a stopword → reject" rule (the same rule that turns "expert-level
  experience with kubernetes" into prose, not a skill) rejects the whole
  slash-phrase unaided. Confirmed via a before/after Node smoke test: the
  pre-fix engine already returned `false` for `financial/insurance`, so no
  code change was made for this one.

Verified via a standalone Node smoke test on `phraseOk` directly (all 5
ported noise phrases now rejected; `ci-cd`/`scikit-learn`/`node-js`/`k8s`/
`power bi` still pass through untouched) and a before/after diff against the
unmodified engine (git-stashed) confirming `awareness`/`dna`/`expect`/
`shell/power`/`power` flipped `true` → `false` while `financial/insurance`
was `false` on both sides.

### 3.7 2026-07-22 sync: airline crew-member boilerplate and a garbled service-list line

A second real-world JD (JetBlue, Senior Core Infrastructure Engineer) scored
92.3% curated but only 1/29 on the dynamic-phrase check — and that lone
"match" (`developers`) was itself noise, not a real skill overlap. Root
cause: airline-industry crew-member/regulatory/values boilerplate that a
generic tech-JD scorer has no reason to expect —

- **Values statement**: JetBlue's "Safety, Caring, Integrity, Passion and
  Fun" — `caring`, `fun`, `safety` joined `SOFT_SKILLS` (`integrity` was
  *already* there from the general HR-taxonomy list — no port needed).
- **Aviation/regulatory jargon**: `sar`, `asap`, `aviation safety action`,
  `safety action report`, `safety ambassador`, `sms` (Safety Management
  System, not text messages), `faa`, `osha`, `dot`, `sarbanes`, `oxley act`
  (the two halves of "Sarbanes–Oxley Act" — `sox` itself is already
  curated separately).
- **HR/education boilerplate**: `diploma/ged`, `pre-employment` (drug
  test), `business-wide`. (`work-streams` and `developers` were **already**
  rejected pre-fix — `work` and `developer(s)` are both plain `STOPWORDS`
  entries from the general job-title/generic-aptitude list — no port
  needed for either.)
- **Garbled extraction from a slash-heavy line** ("AKS/EKS Azure Data
  Lake/ Glacier, CosmosDB / DynamoDB"): `lake` (a residual fragment of the
  already-curated `data lake`), `pci/personally`, and `eks azure data`
  (cross-slash/cross-line grabs) — all extraction artifacts, not real terms.
- **`payment card industry`** — the spelled-out form of the already-curated
  `pci` alias. Added directly to the `compliance` canonical's alias list
  (`["compliance","soc 2","soc2","hipaa","pci","payment card industry",
  "fedramp",...]`) rather than to `SOFT_SKILLS`, since this one is a genuine
  curated-skill alias, not noise to discard.

Deliberately did **not** port a noise-listing for `chatgpt`: unlike
JetBlue's usage (a "using ChatGPT during the interview disqualifies you"
clause), the Python-side corpus check showed `chatgpt` recurring as a
*genuine* AI-tool skill mention in five other JDs ("Experience using
AI-assisted development tools such as GitHub Copilot, Cursor, ChatGPT,
Claude..."). Blanket-noising it would suppress a real signal elsewhere —
the same discipline as not porting `financial/insurance` in §3.6, applied
in the opposite direction (a phrase that looks like noise in one JD but
isn't noise in general).

Verified via a standalone Node smoke test on `phraseOk` directly: all 20
ported phrases now rejected, the 3 phrases that needed no port
(`integrity`, `work-streams`, `developers`) were confirmed already-`false`
pre-fix, and `findCurated("...Payment Card Industry compliance...")`
resolves to the `compliance` canonical.

### 3.8 2026-07-22 sync: on-call/work-schedule boilerplate (clock times, an "Hours" header, a "*-regulated" adjective)

A third real-world JD (Elucid, Principal Platform Engineer) scored 90.3%
curated but 0/3 on the dynamic-phrase check, despite the candidate having
every real skill the JD asked for. All three "JD-specific phrases" were
schedule/environment boilerplate, not skills:

- **`am`/`pm`** — clock-time markers from an on-call-window sentence
  ("...coverage on business days from 9:00 AM to 12:00 AM"). The all-caps
  abbreviation Title-Case-matches the proper-noun extractor the same way a
  weekday or month name does, so it belongs in `TIME_WORDS` alongside them.
- **`hours`** — from a "Work Location and Hours:" section header
  (Title-Case again). Added to `STOPWORDS` next to the existing
  `day`/`week`/`month`/`year` generic time-unit nouns — it was a plain
  oversight that `hour`/`hours` weren't already there.
- **`fda-regulated`** — a hyphen-adjective compound describing the work
  environment ("architect secure automated systems in an FDA-regulated
  environment"), same grammatical family as the already-noise-listed
  `-compliant`/`-critical`/`-prone`/`-safety` suffixes in `HYPHEN_ADJ` — not
  a discrete tool/skill name. Added `regulated` to that suffix alternation
  (so `sec-regulated`, `state-regulated`, etc. are covered too, same as the
  Python side).

Deliberately left the bare `fda` token unmatched rather than blanket-
suppressing it: "Food and Drug Administration" is a real regulatory body
relevant to medtech compliance work, so once the `-regulated` adjective
noise is stripped, a standalone `fda` mention is a genuine potential
domain-experience gap to flag, not noise to discard — same discipline as
the `chatgpt` non-port in §3.7, applied to a phrase surfacing rather than
one being suppressed.

Verified via a standalone Node smoke test on `phraseOk` directly: `am`,
`pm`, `hours`, `fda-regulated`, `sec-regulated`, and `state-regulated` all
now rejected.

### 3.9 2026-07-22 sync: a sentence-opener and finance-industry organizational descriptors

A fourth real-world JD (Millennium, Cloud Platform / Infrastructure
Engineer) scored 82.5% despite 100% curated match — 2 of 4 dynamic
phrases were noise:

- **`beyond`** — a Title-Case sentence-opener ("Beyond immediate
  delivery, you'll help define platform infrastructure best practices...").
  Added to `STOPWORDS` next to the other prepositions (`about`, `across`,
  `between`, etc.) it already sits alongside on the Python side.
- **`front-office`** — a finance-industry organizational descriptor
  ("front-office trading teams"): which business function a system
  serves, not a technology. Same grammatical family as the existing
  `-compliant`/`-critical`/`-regulated` `HYPHEN_ADJ` suffixes, so `office`
  joined that alternation (covering `front-office`, `back-office`, and
  `middle-office` in one shot). The `-office` family recurs across the
  corpus (Millennium, SumUp, ToScale, Vertafore), always in this same
  organizational sense — never a false positive against a real tech name.

Verified via a standalone Node smoke test on `phraseOk` directly: `beyond`,
`front-office`, `back-office`, and `middle-office` all now rejected.

### 3.10 2026-07-22 sync: a bullet-opening verb (partial port — company-name noise deliberately skipped)

A fifth real-world JD (Talon — actually a Bloomberg posting saved under a
non-Bloomberg filename) scored 60.4% on the Python side despite 89.3%
curated match: 5 of 6 dynamic phrases were noise. Only one of the five
generalizes to this app:

- **`discover`** — a bullet/sentence-opening verb ("Discover what makes
  Bloomberg unique..."), same family as the existing `RESP_VERBS` set
  (`recommend`, `ensure`, `establish`, ...). Added to `RESP_VERBS`. Verified
  via Node smoke test: `respVerb("discover")` → `true`, `phraseOk("discover")`
  → `false`, and the gerund form (`discovering`) still resolves correctly
  through the existing suffix-stripping logic.

The other four **do not port**, for the same reason `coreweave`/`transcend`/
`comcast` (§3.4, §3.6) never did:

- **`bloomberg`**, **`cnci`** — the employer name and its internal team
  acronym (Cloud Native Compute Infrastructure). These are noise only because
  they're proper nouns specific to one real employer in the author's own job
  search; this app's `employerTerms()` derives the brand from the JD text
  itself (EEO self-reference, corporate self-intro, "At X, we..." pitch,
  brand-narrative openers) rather than from a filename, so it's already a
  *different, filename-independent* mechanism than the Python side's bug (a
  JD saved under a mismatched filename). Confirmed neither this JD's
  self-intro shape ("Bloomberg runs on data!") nor Bloomberg-specific team
  jargon would be caught by any *general* brand-detection rule worth adding —
  hardcoding one company's name into a bilingual, multi-employer scoring
  engine isn't a generalization, it's exactly the per-JD noise this app's
  architecture is designed to avoid needing.
- **`business area`**, **`ref`** — Bloomberg careers-site template field
  labels ("Location / \<city\> / Business Area / \<dept\> / Ref # / \<req
  number\>", one label per line with no colon). `METADATA_LINE` already
  strips this *class* of line generically, but only in `key: value` shape;
  loosening its colon requirement to match label-only lines would risk
  stripping real prose that happens to start with a word like "location"
  ("Location flexibility is a core value here.") since the line-start match
  has no trailing anchor to fall back on. Not a safe, zero-maintenance
  generalization the way a `HYPHEN_ADJ` suffix or `TIME_WORDS` entry is —
  left unported, same call as skipping the Python-only "Recruitment Fraud
  Alert" header fix in §3.5.

### 3.11 2026-07-23 sync: employer-domain split, a generic verb, and a marketing-adjective suffix

A sixth real-world JD (Appgate) scored 59.3% on the Python side despite
93.3% curated match: 6 of its 13 dynamic misses were noise, each a
distinct root cause rather than one recurring pattern. Four generalize here:

- **`appgate.com`** — the employer's own domain from a "Learn more at
  appgate.com" line. The employer-noise check split phrases on
  `[ /-]+` only, never `.`, so the domain's dot never separated it from
  the derived employer term. Extended the split to `[ /.-]+` in the
  `extractDynamicPhrases` employer check. Verified via Node: with an
  employer term of `appgate` present, `"appgate.com".split(/[ /.-]+/)`
  now yields `["appgate", "com"]`, matching. Safe for the same reason as
  the Python side: a real skill token that happens to share a bare word
  with the employer name (e.g. `node` for a Node.js-themed JD) is already
  excluded from `employerTerms()`'s output via its `CURATED_TOKENS` guard.
  Note this app has no filename-based employer derivation at all (users
  paste text, not a `job_desc_<company>.txt` file) — for the *actual*
  Appgate JD text, none of `employerTerms()`'s three text patterns (EEO
  self-reference, "is a/an company", "provides/builds/...") happen to fire
  on Appgate's specific self-intro wording, so this fix is verified correct
  in isolation (Node test with a matching self-intro) rather than against
  the real JD end-to-end — a separate, pre-existing gap in this app's
  employer-detection coverage, not something to expand now.
- **`test`** — a bare single-word verb, generic and never a skill alone
  (real test-related skills are always multi-word: "unit testing",
  "penetration testing"). Added to `RESP_VERBS`. Verified: `respVerb("test")`
  → `true`, `phraseOk("test")` → `false`, `respVerb("testing")` → `true`.
- **`direct-routed`** — Appgate's own product-marketing adjective ("the
  only direct-routed Zero Trust solution"), same family as the existing
  `HYPHEN_ADJ` suffix set (`-based`, `-driven`, `-native`, ...). Added
  `routed`. Verified: `HYPHEN_ADJ.test("direct-routed")` → `true`,
  `phraseOk("direct-routed")` → `false`.
- **`ztna`** / **`zero trust network`** — literal synonyms of the
  already-curated `zero trust` (Zero Trust Network Access is the same
  concept, not a distinct skill) — aliased onto it, same pattern as
  existing acronym/expansion pairs (`sso`, `waf`). Verified:
  `CURATED_TOKENS.has("ztna")` → `true`.

One Python-side fix does **not** port:

- **Unbalanced-paren rejection** — the Python bug this fixes ("stateful
  technologies (e.g. kafka" as a mangled comma-split fragment) arises
  because Python's `_SKILLS_LINE_RE` matches on a header *word* alone,
  independent of whether the rest of the line actually looks like a list.
  This app's source-1 skill-list extraction is structurally immune: it
  requires **all** comma/colon/paren-split items to be short (≤4 words)
  before treating a line as a list at all (`extractDynamicPhrases`'s
  `items.every(i => i.split(/\s+/).length <= 4)` gate), so a
  responsibility-bullet sentence with a parenthetical example list never
  qualifies as a skill-list line here in the first place — there's no
  observed failure mode to fix. Adding the same defensive check anyway
  would be speculative complexity with no verified trigger, so it's
  skipped (same reasoning as declining to port fixes for bugs that don't
  reproduce in this app's different extraction design, e.g. §3.5's
  Python-only header fix).

Genuine gaps intentionally left alone on the Python side (not ported here
either, since they're not noise): `kubeflow`, `mlflow`, `agentic ai`,
`experiment-tracking`, `sase`, `sdp`, `tunneling/overlay` (dynamic) and
`sagemaker`, `secure-by-default`, `vpn` (curated) — real MLOps and
Zero-Trust-adjacent-networking terms, not extraction bugs.

### 3.12 2026-07-23 sync: an interview-integrity disclaimer and two curated terms

A seventh real-world JD (JetBlue) hit an extreme case of the harmonic-mean
confidence-ramp cliff on the Python side: 92.3% curated match but 0 of 7
dynamic phrases matched, so the harmonic mean of (curated, dynamic)
collapsed straight to 0 and the JD scored 30.0% overall despite the strong
curated match. All three fixes generalize here:

- **AI-interview-integrity disclaimer** — JetBlue's JD warns "The use of
  ChatGPT or any other automated tool during the interview process will
  disqualify a candidate…", which names an AI tool only to prohibit using
  it live in the interview, not as a skill ask. This is deliberately NOT a
  blanket "chatgpt is noise" rule — other real JDs in the Python corpus
  (earnin, hud, netboxlabs) list ChatGPT/Copilot/Cursor as genuine
  AI-assisted-development skill signals, so blocklisting the word itself
  would wrongly zero those out. Added `AI_INTERVIEW_INTEGRITY`, a line-scoped
  test (mirrors the Python `_AI_INTERVIEW_INTEGRITY_RE`) that only fires
  when an AI/automated-tool mention, "interview", and "disqualif*" all
  appear on the same line — order-independent via lookaheads. Verified via
  Node: the disclaimer line is stripped (`chatgpt` no longer present after
  `prepJD`), while a genuine "AI-assisted development tools... ChatGPT..."
  mention survives untouched.
- **`opentofu`** — OpenTofu is Terraform's drop-in-compatible open-source
  fork; JDs phrasing it as "Terraform/OpenTofu" mean either is acceptable,
  so real Terraform experience already satisfies it. Aliased onto the
  existing curated `terraform`. Verified: `CURATED_TOKENS.has("opentofu")`
  → `true`.
- **`pii`** — Personally Identifiable Information is a standard compliance
  term in the same family as the already-curated `hipaa`/`pci`/`soc 2`.
  Curated as a new Security & Compliance term (with the Arabic equivalent,
  matching this app's bilingual convention). Verified:
  `CURATED_TOKENS.has("pii")` → `true`.

Not ported: the Python side also added a `tailor_resume.py` backstop
(`ensure_jd_dynamic_phrases`) so a hand-added base-resume term with no
KEYWORD_DB entry (e.g. "Glacier") can't be silently dropped by the LLM
rewrite. This app has no resume-tailoring/LLM-rewrite step — it only
scores whatever text the user pastes — so there's nothing analogous to
backstop here.

### 3.13 2026-07-23 sync: an "X-to-Y" compound, two adjective suffixes, and inline slogan hashtags

An eighth real-world JD (Paramount) had 96.2% curated match but only 2/22
dynamic phrases, mostly marketing/brand noise from a duplicated "About
Paramount Streaming" self-description paragraph. The Python side also found
a broader structural bug there (`_SKILLS_LINE_RE`'s hyphen-separator form
had no spacing requirement, so "platform-wide observability." false-fired
on the header word "platform" immediately followed by "-"), but this app's
skill-list extraction (`items.every(i => i.split(/\s+/).length <= 4)`, no
header-word regex at all) is structurally immune to that one, same as
§3.11's paren-balance finding — confirmed no port needed there.

What does generalize:

- **`direct-to-consumer`** — an "X-to-Y" relationship/business-model
  compound (business-to-business, peer-to-peer), never a tool name. Added
  `TO_COMPOUND = /-to-/`. Verified: `phraseOk("direct-to-consumer")` →
  `false`.
- **`world-renowned`**, **`platform-wide`** — generic marketing/scope
  adjectives; added `renowned` and `wide` to the existing `HYPHEN_ADJ`
  suffix set.
- **`inter-service`** — "inter-" always describes a relationship between
  things, never a tool; added to the existing prefix set alongside
  non-/anti-/semi-/no-/co-.
- **`#WeAreParamount`** — an inline (not whole-line) slogan hashtag; this
  app had no hashtag-stripping mechanism at all yet (the Python side's
  whole-line-only stripper doesn't port cleanly to a single-pass `prepJD`
  either). Added `HASHTAG_WORD`, scoped to CamelCase-slogan/ALL-CAPS
  hashtags so a genuine inline tech hashtag ("we use #kubernetes daily")
  survives untouched — same closed-set reasoning as the Python fix, ported
  as a new mechanism since none existed here yet.
- **`hpa`** — already curated here (aliased onto `autoscaling`) from an
  earlier round; no change needed.

Verified via Node: `phraseOk` rejects all three grammar-shape phrases above,
`prepJD` strips `#WeAreHiring`/`#DISNEYTECH` while keeping `#kubernetes`.

Not ported: Paramount's own sub-brands (`pluto tv`, `showtime`) and internal
team name (`applied intelligence personalization`) — one-off, no
generalizable regex shape, same call as skipping Bloomberg's `cnci` in
§3.10. The Python side's reverted `error-budget` curation attempt (caused a
cliff regression — see the Python RESEARCH notes) was never attempted here
in the first place, so there's nothing to revert.

### 3.14 2026-07-23 sync: a ninth real-world JD (Talkiatry) finds a header-orphan
bug in *both* engines, ported only what's safe here

Talkiatry: 93.5% curated (only genuine gaps: react, typescript) but 0/4
dynamic phrases — all noise. Two ported cleanly:

- **`scale-up`** — a company-stage descriptor ("startup or scale-up"), not a
  skill. Added to `SOFT_SKILLS` alongside the existing `fintech`-style
  industry bucket.
- **`tele-health`** / **`telehealth`** — an industry-vertical descriptor
  (healthcare sub-sector), same bucket. Added to `SOFT_SKILLS`.
  Verified: `phraseOk` rejects `scale-up`, `scaleup`, `telehealth`,
  `tele-health`.

One NOT ported, deliberately, after a real investigation: the Python side's
`_true_run_start` fix (a 4+-word Title-Case header like "How Success Is
Measured" gets split by `_PROPER_RE`'s 3-word cap, orphaning the tail word
"Measured" past the sentence-boundary filter). This app's proper-noun loop
has no word-count cap (`while` loop extends a chain as far as consecutive
Title-Case words go), so the Python bug's specific mechanism (the cap) isn't
present — but a **different-shaped version of the same symptom** is:
`extractDynamicPhrases("How Success Is Measured")` still yields
`[["success", 0.5], ["measured", 0.5]]`, because "Is" is capitalized but too
short to match the `^[A-Z][a-z]{2,}$` word-shape regex, breaking the chain
and letting both fragments either side of it restart as "fresh" captures.

The tempting fix — treat any capitalized `words[i-1]` (even one that failed
the shape regex) as "still inside the opening run, keep suppressing" — was
built and tested, then **rejected** before porting: it also suppresses the
extremely common "Capitalized-verb Capitalized-tool" bullet shape, e.g.
`extractDynamicPhrases("Deploy Databricks and Snowflake automation.")`
currently correctly yields `[["databricks", 0.5]]` (a genuine, valuable
capture — line-leading responsibility verbs followed by a real tool name are
one of the most common bullet shapes in this corpus), and the "still
capitalized" heuristic would zero it out. The two cases are
indistinguishable by capitalization alone; the Python fix works because it
operates on a bounded regex-cap artifact, not on capitalization sequencing,
and that mechanism has no analog here. Distinguishing the two shapes properly
would need either a short-function-word list (Is/To/Of/On/…) scoped only to
suppressing continuations, or the (much larger) `respVerb`-based line
analysis the skills-line source already has (§1, `items` branch) ported into
the proper-noun branch too — deferred as real follow-up work, not attempted
under time pressure given the risk of silently breaking the far more common
verb+tool pattern. Left as a known, minor, occasional single-common-word
noise leak (previously observed on Talkiatry's own JD, harmless there since
`measured`/`success` don't crowd out any genuine dynamic phrase in that
document).

### 3.15 2026-07-24 sync: a tenth real-world JD (Anori) — one phrase ports
1:1, the other surfaces as a different shape entirely

Anori: 100% curated (16/16) but 0/3 dynamic phrases, tanking the harmonic
mean to 65.0% on the Python side despite the resume genuinely covering
everything real in the JD. Two of the three were noise:

- **`productivity/sdlc`** — from "developer productivity/SDLC". Ports 1:1:
  same curated-fragment-in-a-slash-compound shape as the existing
  `shell/power` entry. Added to `SOFT_SKILLS`. (Note: the Python engine's
  `sdlc` curated term doesn't exist anywhere in this app's `KEYWORD_DB` — a
  separate, pre-existing gap discovered along the way, not part of this
  port and not fixed here.)
- **`cd excellence`** — the Python side's orphan tail of "CI/CD Excellence:"
  (`ci/cd` already curated, leaving "CD Excellence" as a 2-word leftover
  run). Does **not** port as that phrase: this engine's proper-noun run
  requires Title-Case (`^[A-Z][a-z]{2,}$`), so the all-caps "CI/CD" never
  starts a run in the first place — the chain instead starts fresh at
  "Excellence", surfacing as a **bare single word**, not a 2-word phrase.
  Verified with a scratch Node harness (`extractDynamicPhrases` on the
  Anori JD text) before deciding what to stoplist — confirmed `excellence`
  alone leaks, not `cd excellence`. Added `excellence` to `SOFT_SKILLS`
  instead of porting the Python string verbatim.

The third missing phrase, **`elt`** (from "Modern Data Stack: Experience
with ELT orchestration tools"), is a genuine gap on the Python side — no
ETL/ELT/data-pipeline experience anywhere in the base resume. It needed no
action here at all: this engine's proper-noun regex only matches Title-Case
words, so the all-caps "ELT" never gets extracted as a phrase in the first
place. It's simply invisible rather than noise — a structural blind spot
for acronym-shaped genuine skills too, not something this fix introduced or
could regress, and out of scope to address here.

Verified post-fix with the same scratch Node harness: `phraseOk("excellence")`
and `phraseOk("productivity/sdlc")` both now return `false`, and
`extractDynamicPhrases` on the full Anori JD snippet no longer yields either.

### 3.16 2026-07-25 sync: an eleventh real-world JD (HII) — most of the
Python fix turns out to already not apply here

HII: 100% of the real requirements genuinely met but 39.9% FAIL on the
Python side, dragged down by 10 dynamic-phrase false positives. Verified
each one against this engine's actual extraction (scratch Node harness,
same method as §3.15) before touching anything — most needed no porting at
all, because this engine's shapes are already stricter or already cover the
case:

- **`travis-ci`** — a genuinely uncurated CI tool (Travis CI) sitting beside
  two already-curated siblings (`jenkins`, `gitlab`) in the same
  "(e.g. Gitlab-CI, Travis-CI, Jenkins, etc.)" list. Ported the same way as
  the Python side: added `"travis ci": ["travis-ci", "travis ci",
  "travisci"]` to `KEYWORD_DB`'s CI/CD & Automation category, rather than
  stoplisting it — the resume's lack of Travis CI experience should cost a
  curated-tier miss, not a dynamic-tier one.
- **`distribution`** — from "Cloudera's Distribution of Hadoop". Ports 1:1:
  the possessive apostrophe and lowercase "of" fragment the run down to the
  bare word "Distribution" here exactly as they do in the Python engine.
  Added to `SOFT_SKILLS`.
- **`columbia`** — the office location ("Columbia, MD"). Ports 1:1 into the
  existing `CITY_NOISE` gazetteer (this engine's `_CITY_NOISE` equivalent).

Everything else needed **no action**, verified structurally invisible or
already handled rather than assumed:

- **`enlighten`** (the actual hiring brand — HII's Mission Technologies
  division) is caught **automatically** by `employerTerms`'s "At `<Brand>`,
  we/our/you" pattern (`At Enlighten, our team's unwavering work ethic…`) —
  a self-reference convention this engine's `employerTerms` already checks
  for that the Python engine's `_employer_terms` does not. No stoplisting
  needed; confirmed via the harness that `employerTerms(jd)` already
  contains `"enlighten"` on the unmodified file.
- **`mid-senior`**, **`travis-ci`** (as a bare hyphenated token, before
  curating it), **`dod`**, **`disa`**, **`mapr`** are all structurally
  invisible: this engine's proper-noun regex (`^[A-Z][a-z]{2,}$`) requires
  an all-lowercase tail after the leading capital, so any word with an
  internal capital (`DoD`, `MapR`) or that's ALL-CAPS (`DISA`) never
  matches, and a hyphen isn't whitespace, so `Mid-Senior`/`Travis-CI` never
  start a Title-Case run at all. None of these ever reach the dynamic pool
  here — confirmed absent from `extractDynamicPhrases(jd)` output on the
  unmodified file.
- **`diploma`** is absorbed even more thoroughly than the above: this
  engine's word-merge loop welds the full run "High School Diploma"
  together in one pass (no Python-side "OR"-before-a-capitalized-word
  truncation quirk splitting it down to a bare last word), and `phraseOk`'s
  per-part stopword check rejects the WHOLE 3-word phrase the moment `high`
  trips it — `diploma` alone never surfaces.
- **`mid`** / **`travis`** (the Python-side bare halves left over once the
  longer phrases are filtered) never applied here in the first place, since
  the longer phrases were never extracted to begin with.

Left alone as genuine gaps (same call as the Python side): **`big data`**
and **`hadoop`** (a real, if generic, tech category / specific distro the
resume doesn't claim). Also discovered along the way, pre-existing and
explicitly NOT fixed as part of this port (same category as `sdlc` in
§3.15): **`maven`** and **`vmware`** are curated in the Python engine but
don't exist anywhere in this app's `KEYWORD_DB` — a gap in the curated
dictionary's breadth, unrelated to this round's noise fix.

Verified post-fix with the same scratch Node harness: `CURATED_TOKENS.has(
"travis-ci")` and `CURATED_TOKENS.has("travis ci")` both now return `true`,
`SOFT_SKILLS.has("distribution")` and `CITY_NOISE.has("columbia")` both now
return `true`, and re-running `extractDynamicPhrases` on the real
`job_desc_hii.txt` text no longer yields any of the three.

---

### 3.17 2026-07-31 sync: a twelfth real-world JD (UofC) — an "Application
Documents" ATS checklist header leaks `resume/cv`

University of Chicago Staff Platform Engineer posting: 39.9% -> 45.2% FAIL
on the Python side despite every listed tool being genuinely covered once
curated. Root cause: the ATS application checklist ("Application Documents /
Resume/CV (required) / Cover Letter (preferred)") sits BEFORE this JD's "Pay
Range" header, which the existing trailing-boilerplate cutter (`TAIL_HEADINGS`)
already truncates at — just too late to catch this earlier section.

Verified via the same scratch Node harness (extract `<script>`, stub
`document`/`window`/`navigator`/`localStorage`, `require()` and call
`prepJD`/`extractDynamicPhrases` directly) on both a synthetic snippet and
the real `job_desc_uofc.txt` text: on the unmodified file, `resume/cv` (plus
downstream fragments `application documents`, `letter`, `family`, `contributor`,
`impact`, `rate type` — all Title-Case leftovers of the same unstripped tail)
surfaced in `extractDynamicPhrases`'s output.

Fixed by porting the exact same `_BOILERPLATE_TAIL_RE` addition from
`my-resumes/ats_checking.py`: added `application documents` as a `TAIL_HEADINGS`
alternative, right beside the existing `(?:hiring|interview|application)
process` entry. Since this engine's tail-cut only reopens on a real
`JOB_CONTENT` header (never seen again in the rest of a University-ATS
posting — "Job Family", "Pay Rate Type", "Pay Range", the EEO statement are
all boilerplate too), one header addition truncates the whole tail in one
shot; no anchored-block or stoplist changes were needed.

Re-ran the harness post-fix on the real JD: `resume/cv` and all downstream
tail fragments are gone from `extractDynamicPhrases`'s output; `elb/alb`,
`nist`, and `fips` (genuine dynamic phrases from earlier in the posting)
are unaffected.

NOT ported — out of scope for this round, a pre-existing breadth gap between
the two engines' dynamic-phrase extraction (same bucket as `maven`/`vmware`
in §3.16): this engine still surfaces `security frameworks`, `agile
methodologies`, `dynamic language`, `subject matter expert`, and several
single-word Title-Case fragments (`department`, `university`, `microsoft`,
`amazon`, `bedrock`, `center`, `summary`, `production`, `learn`, `full`,
`competencies`) that the Python engine's stricter proper-noun/sentence-
boundary handling doesn't produce on the same text. None of these are
caused by — or fixed by — the `Application Documents` header change; they're
a separate, pre-existing divergence in overall extraction precision, not
today's noise fix.

The corresponding resume-content additions made on the Python side (adding
`SVN`/`FIPS`/`Nginx`/`AWS ELB-ALB`/`Atlantis` to the candidate's actual base
resume) have no analog here — this app scores whatever resume text a user
pastes in, it doesn't own a resume of its own.

---

### 3.18 2026-08-01 sync: a thirteenth real-world JD (AlphaSense) — this engine
had NO leading-"About &lt;Company&gt;" excision at all, plus a corpus-wide DF>=8 sweep

The 796-JD corpus's growth (up from ~672 at §3.16/3.17) triggered a fresh
`jd_noise_audit.py` pass on the Python side, which surfaced two categories of
fix: a specific leak from `job_desc_alphasense.txt` (AlphaSense's "About
AlphaSense" intro narrates its 2024 acquisition of Tegus by name, leaking
`tegus` as a bogus Title-Case dynamic phrase) and five DF>=8 recurring noise
phrases (`wir`, `customer`, `crm`, `argo`, `health`) plus a job-title/role
word (`evangelist`) the audit's own document-frequency principle flags as
boilerplate, not company-specific skills.

**The `tegus` leak was a bigger structural gap here than in §3.17.** The
Python fix generalized `_LEADING_ABOUT_COMPANY_RE`'s "first real content"
check (it only fired when the text before a bare `About <Company>` header was
exactly `""` or `"about the job"`) to also allow a short title/metadata
preamble via a new `_is_leading_metadata_prefix` helper. But this engine had
**no equivalent of `_LEADING_ABOUT_COMPANY_RE` at all** — `INTRO_HEADINGS`
only recognizes the generic literal forms ("About Us", "About the Company"),
never a bare company NAME ("About AlphaSense"). So this wasn't a narrow
one-line port; it required adding the whole mechanic fresh.

Verified via the usual scratch Node harness (extract `<script>`, stub
`document`/`window`/`navigator`/`localStorage`/`performance`, `require()` and
call `prepJD`/`extractDynamicPhrases` directly). Confirmed pre-fix:
`extractDynamicPhrases` on the real `job_desc_alphasense.txt` text yielded
`founded`, `rancher`, and `tegus` — the intro paragraph leaking straight
through untouched.

Fixed by adding, ported 1:1 in spirit from the Python side:
- `LEADING_ABOUT_COMPANY` — a regex matching a bare `About <Word>` header,
  excluding the same generic-word negative lookahead
  (`the|us|our|this|your|these|what|how|why|working|life|career|careers|
  role|roles|opportunit`) as `_LEADING_ABOUT_COMPANY_RE`.
- `isLeadingMetadataPrefix(lines, uptoIdx)` — the guard mirroring
  `_is_leading_metadata_prefix`: refuses to fire if the prefix has more than
  6 non-blank lines, if any prefix line matches `JOB_CONTENT` (a real header
  proves the job body already started), or if any line is longer than 120
  chars / 12 words (real prose vs. a title/company/date label). This is what
  keeps a mid-document "ABOUT AWS" block sitting after "Responsibilities"
  (the exact `job_desc_aws_proserve.txt`-style case the Python docstring
  warns about) from being nuked — verified with the same synthetic
  Responsibilities-then-ABOUT-AWS snippet used in the Python test suite.
- Wired into `prepJD` as a new step 0, before the existing `INTRO_HEADINGS`
  loop, splicing out the header-to-next-`JOB_CONTENT` span exactly like that
  loop already does for the labeled-header case.

One divergence found and fixed during verification, not present on the
Python side: this engine's `JOB_CONTENT` regex is a single combined pattern
that ALSO matches LinkedIn's `"About the job"` chrome line (via its `"about
the (?:role|job|position|opportunity)"` alternative) — Python keeps that
chrome-recognizing pattern in a separate constant (`_JOB_CONTENT_START_RE`)
from the one that bounds the leading-excision (`_JOB_CONTENT_HEADER`), so the
chrome line never trips its own guard. Ported by having
`isLeadingMetadataPrefix` explicitly treat an exact `"about the job"` line as
invisible chrome before checking the rest against `JOB_CONTENT` — otherwise
the alphasense JD's own `"About the job"` line was self-defeating the guard.

Re-ran the harness post-fix: `tegus` (and `founded`, a harmless companion
Title-Case pickup from the same sentence) are gone; `rancher` remains
correctly present as a dynamic phrase (see below — it's not curated in this
app's `KEYWORD_DB`, a separate pre-existing gap).

**Corpus-wide diff, not just alphasense**: re-ran `extractDynamicPhrases`
over all 796 `job_desc_*.txt` files before/after (via `git stash`/`git stash
pop` to snapshot the pre-fix engine) to check for unintended fallout. 45
files changed, and the change is a broad, unambiguous noise reduction — VC
firm names, funding-round mentions, and brand narrative fragments dropped out
of `job_desc_arca.txt`, `job_desc_assembled.txt`, `job_desc_clay.txt`,
`job_desc_fora.txt`, `job_desc_klarity.txt`, `job_desc_kodi.txt`,
`job_desc_plenful.txt`, `job_desc_ridecell.txt`, `job_desc_wolfellc.txt`, and
others that all share the same "About &lt;Company&gt;" marketing-intro
convention alphasense does. No file lost a phrase that looked like a genuine
skill; the one addition worth checking (`job_desc_arca.txt` gained `one`,
`job_desc_asrc_cde.txt` gained `sast`) turned out to be a real skill
(`sast` = Static Application Security Testing, genuinely present in that
JD's text) surfacing cleanly once the surrounding noise no longer disturbed
the sentence-boundary split — not a regression.

**The DF>=8 sweep — only `argo` needed a port.** Checked each of the five
audit offenders against this engine with the scratch harness before touching
anything (same "verify before fixing" discipline as every prior round):
- `argo` DOES leak here, same root cause as the Python side — it's a
  fragment of the already-curated `argocd` alias (`"argocd": ["argocd", "argo
  cd"]`); JDs narrate the umbrella CNCF Argo project ("the Argo ecosystem",
  "administering Argo projects (e.g., Argo CD, Argo Rollouts)") and the
  Title-Case run sometimes captures the bare word alone. Confirmed against
  the real `job_desc_leaflink.txt` and `job_desc_akuity.txt` text. Added
  `"argo"` to `SOFT_SKILLS`.
- `wir` (German "we"), `customer`, `crm`, `health` needed **no action** —
  none leaked even from realistic snippets modeled directly on the corpus
  text that trips them on the Python side. This engine's proper-noun
  extraction requires a Title-Case run; plain-lowercase prose words are never
  candidates at all here, unlike the Python engine's separate all-lowercase
  skills-line and punctuated-token sources that catch them. Documented inline
  next to the `"argo"` addition rather than silently skipped.
- `evangelist` (the job-title/role word this round's other flagged item,
  `"Evangelist of highly performant CI/CD practices…"`) also needed no
  action here for the same structural reason: a single capitalized word
  followed by a lowercase word never forms a multi-word Title-Case run, so it
  was never a candidate phrase on this engine to begin with. Verified with a
  targeted snippet; not added to `SOFT_SKILLS`.

NOT ported — out of scope, same pre-existing-breadth-gap bucket as
`maven`/`vmware` (§3.16) and the single-word Title-Case fragments (§3.17):
`rancher` is curated in `KEYWORD_DB` on the Python side (added to the
candidate's base resume this round — genuine MedAllies experience) but was
never curated here, so it correctly still surfaces as an uncurated dynamic
phrase in this app. Adding it to this app's `KEYWORD_DB` is a separate
curated-breadth task, not a noise fix, and wasn't requested for this round.

---

### 3.19 2026-08-01 sync: the "university-posting" JD family (pennstate,
carnegie, stanford, uwisconsin) — four postings, four different noise shapes

Same day as §3.18, the candidate flagged that the university/national-lab
posting family fails broadly on noise, not just AlphaSense. Went through
`job_desc_pennstate.txt` (Penn State ARL), `job_desc_carnegie.txt` (Carnegie
Mellon), `job_desc_stanford.txt` (SLAC/Rubin Observatory, hosted at
Stanford), and `job_desc_uwisconsin.txt` (UW-Madison) one at a time, fixing
the Python side first (`my-resumes/ats_checking.py` — see that repo's commit
history the same day) then re-verifying each fix against this engine with the
scratch harness before porting, since the two engines' proper-noun
extraction shapes diverge enough that assuming symmetry has been wrong in
every prior round.

**pennstate**: government/defense security-clearance boilerplate (ARL's
"Unclassified, Controlled Unclassified Information (CUI), and Classified
information" paragraph; "the Navy, the Intel Community (IC)") plus a Workday
application-instructions "CURRENT PENN STATE STUDENT" block. `ic`/`cui`/
`student` need **no action** here — all-caps acronyms never match this
engine's Title-Case-with-lowercase-tail proper-noun regex, and "STUDENT"
(also all-caps) doesn't either. `classified`/`unclassified` DID need porting,
but the same whack-a-mole pattern the Python side hit (§3.18's `sast`
addition, `job_desc_arca.txt`'s `one`) recurred here twice over: filtering
the compound "Controlled Unclassified Information" un-masked the standalone
word underneath it, so both the phrase AND its bare word needed a
`SOFT_SKILLS` entry. Also added: `applied research laboratory` (ARL's own
name — same "filename-derivation misses the sub-brand" bucket as HII's
"Enlighten" in §3.16), `checks/clearances`, `intel community`, `navy`,
`workday` (this app had no equivalent of the Python `NOISE_PHRASES`
ATS-platform-name bucket — greenhouse/lever/bamboohr/workday), and a run of
plain capitalized sentence-starters this engine has no defense against at
all (`please`, `employees`, `professional`, `personal`, `notice`, `out`,
`u.s`) plus the hyphen-broken "Cloud-Native Computing Foundation" fragment
(`foundation`) and a CI/CD double-count (`delivery`, `integration/continuous`
— see below, this pair needed a second round).

**carnegie**: `TAIL_HEADINGS` had no entry for the "Location / Job Function /
Position Type / Full Time-Part time / Pay Basis" ATS metadata-field block
trailing the real content, so its slash-compound VALUES
("Software/Applications Development/Engineering", "Full Time/Part time")
leaked whole; ported the Python side's matching `_BOILERPLATE_TAIL_RE`
addition (`job function|position type|pay basis`). Also: `cmu` (self-
reference the filename-derived `carnegie` employer term misses, same bucket
as `arl`/`enlighten`), and an unbulleted "Additional perks include a free
Pittsburgh Regional Transit bus pass…" prose sentence with no
insurance/401k/PTO anchor keyword for the existing `BENEFITS_LINE`
mechanism to key off — ported the Python side's `perks? include` addition
(this engine folds that into `BENEFITS_LINE` itself rather than a separate
preamble regex, since `BENEFITS_LINE`'s "keyword to end-of-line" replace
already gets the same result here). `therefore` and `apply` — capitalized
sentence-starters ("Therefore, we are in search…", "Apply today!") — round
out the noise; carnegie went from leaking noise on nearly every phrase to a
clean extraction.

**stanford**: SLAC/Vera-C.-Rubin-Observatory/LSST project-specific jargon —
`data management`/`dm` (the "Data Management (DM) team" name), `prompt
processing framework`, `rubin observatory`/`vera`/`rubin` (astronomer Vera
Rubin's name, fragmenting the same way company names do), `lsst`'s own
expansion "Legacy Survey of Space and Time" breaking at the stopwords
"of"/"and" into `legacy survey` + `space` + `time` (three separate fragments
of one name — `lsst` itself never leaks, all-caps), `slac national
accelerator` + `laboratory` (the 4-word org name overrunning this engine's
Title-Case run cap the same way `applied research laboratory` didn't for
pennstate — different cap length, same failure mode), and `pacific time`
(a timezone reference). Also found a **new structural gap**: a "SLAC
Employee Competencies" section (one-liner soft-skill definitions like
"Effective Decisions: Uses job knowledge...") doesn't fit this engine's
existing anchored-run stripper (`stripAnchoredRuns`, which only strips lines
that are JUST the soft-skill phrase — this JD's lines carry colon +
explanation prose on the same line). Rather than build a second stripper
shape, added `(?:\w+\s+)?employee competencies` to `TAIL_HEADINGS` — it
fires earliest in the document and its cut-to-EOF absorbs the whole
downstream tail in one shot: the competency list itself, an ADA
physical-demands "Physical Requirements And Working Conditions" section, and
an HSPD-12/PIV federal-background-investigation "Work Standards" section.
Also added `physical requirements(?: (?:and|&) working conditions)?` and
`work standards` to `TAIL_HEADINGS` directly, for JDs that carry either
section without a preceding "Employee Competencies" header. Left `keda`
(Kubernetes Event-Driven Autoscaling), `redis streams`, and `influxdb`
untouched — real technologies genuinely absent from the base resume, not
noise; stanford's score improves but correctly stays below the pass
threshold on the Python side for the same reason.

**uwisconsin**: UW-Madison's own division/program/cert-body acronyms
(`uw`, `doit`, `regulated research`, `research cyberinfrastructure` +
bare `cyberinfrastructure` — the same whack-a-mole as
classified/unclassified above — `ssp`, `universities`, `c3pao`, `cmmc`,
`cto office`), `controlled unclassified information` (a clean 3-word
Title-Case run here, unlike pennstate's comma-broken phrasing — same
literal string, needed the same `SOFT_SKILLS` entry independently),
`payable/reimbursable`, `per university` (capitalized only because "Per"
opens its sentence), and a batch of ATS field-label residue: "Job
Category:"/"Job Profile:"/"Job Summary:" each orphan `category`/`profile`/
`summary` the same way pennstate's "Job Description" orphaned `description`
— the label word "Job" is itself a STOPWORD, breaking the 2-word run and
leaving only the field name. Also `level` and the sentence-starters `while`/
`division` (the last one is a straight port of the Python `SOFT_SKILL_STOPLIST`
"generic org-structure noun, same bucket as department" addition — missed
in the first pass of this round and caught by the corpus-wide diff, below).
`serves` ("Serves as technical lead…") needed a `RESP_VERBS` addition
(`serve`, plus `produce` proactively for the same un-covered-inflection
class) — ported from the matching Python `_RESP_VERB_OPENERS` addition.

**Curated-parity fix, not noise**: `cybersecurity` was missing as an alias
of the `security` canonical in this engine's `KEYWORD_DB` (the Python side
already has `"security": ["security", "cybersecurity"]`) — added it. This
is a genuine alias-coverage gap, not a noise bug; low-risk since it only
*adds* a curated match, never removes one.

**Corpus-wide diff caught one true regression and confirmed the rest were
benign.** Same `git stash`/`git stash pop` before/after methodology as
§3.18, run over all ~799 corpus files. `git diff` showed 8 files newly
leaking a *bare* `continuous` — tracked to `integration/continuous`'s fix
above: filtering that garbled slash-fragment un-masks a second, independent
`Continuous` Title-Case word surviving elsewhere in the same sentence
("Continuous Integration/Continuous Development (CI/CD)" — the first
"Continuous Integration" becomes the fragment, the second "Continuous"
survives alone). Added bare `continuous` to `SOFT_SKILLS`; re-diffing then
surfaced the companion fragment `integration` in one further file
(`job_desc_planitgroupllc.txt`'s "Integration application security testing
tools…" bullet opener) — added that too, and the diff came back clean of
`continuous`/`integration` entirely.

The remaining diff noise (`falco` in `job_desc_amtrak.txt`, `dast` in
`job_desc_asrc_cde.txt`, `swift` in `job_desc_walgreens.txt`, plus a handful
of single-letter/number artifacts — `n3`, `ma`, `number`, `clear`, `coast`,
`$90`) is **not a regression**: `extractDynamicPhrases` caps its return at
the top 40 candidates by string length (`kept.slice(0, 40)`), and none of
these three real technology names (`falco`, `dast`, `swift` — none curated
in this app's `KEYWORD_DB`, a separate pre-existing curation-breadth gap,
same bucket as `rancher` in §3.18) changed at the line level when tested in
isolation (confirmed with the harness — identical before/after output for
the exact sentence each appears in). Removing genuine noise elsewhere in
each of those documents freed up slots in the top-40 cap that these
previously-truncated real candidates now fill. Not chased further — it's
the cap doing its job, not a bug introduced this round.

NOT ported — out of scope, same bucket as `rancher` in §3.18: `keda` and
`falco`/`dast`/`swift` are real technologies missing from this app's
`KEYWORD_DB` (Python already curates `falco`/`sast`/`dast` under
"Compliance & Security" and `swift` presumably elsewhere). Curated-breadth
parity is a separate task from this round's noise cleanup.

---

### 3.20 2026-08-02 sync: the "Google Pub/Sub" double-count bug (structurally
different fragmentation shape than the Python fix it ports)

A candidate posting (`job_desc_branch.txt`, Branch — Senior SRE, Java/Spring
Boot/GCP) surfaced a real scoring bug on the Python side, not just a low-fit
resume: the dynamic-phrase extractor double-counted a single JD requirement
as two overlapping fragments. `extract_jd_phrases_weighted`'s Title-Case
source stops right where punctuation starts a following tech token, while
its punctuated-token source independently captures that same token —
"Google Pub/Sub" surfaced as **both** `"google pub"` (from the Title-Case
run, truncated mid-compound) **and** `"pub/sub"` (from the punctuated-token
regex), inflating the dynamic-phrase denominator and unfairly lowering the
score twice for one gap. Fixed in `my-resumes/ats_checking.py` (see that
repo's commit `b7530ca`) by merging such fragments back into one phrase,
verified via text adjacency so unrelated phrases sharing a token never get
merged. Confirmed via an 801-JD corpus diff on the Python side: 36 files
improved (`aws elb/alb`, `azure ad/entra`, `red hat/centos/rocky`, etc.), no
regressions.

Porting to this engine needed a different merge shape, not a copy-paste,
because the two engines' proper-noun extractors fragment differently at the
exact same input — the divergence flagged as a recurring risk in every prior
round (§3.19 above) held again. Python's `_PROPER_RE` matches greedily
against the continuous text and can grab a **partial prefix** of the next
token before hitting punctuation ("Google" + " Pub" match, then stop at
the "/"  — yielding the 2-word fragment `"google pub"`). This engine's
source-3 loop instead tests each whitespace-split token against a **fully
anchored** regex (`/^[A-Z][a-z]{2,}$/`); "Pub/Sub" fails that test outright
(no partial match), so the Title-Case run stops one word **earlier** and
never touches "Pub" at all — yielding the bare 1-word fragment `"google"`.
Confirmed empirically with the scratch Node harness (dumping every
`add()` call) before writing the fix, rather than assuming the Python
merge's "shared last-word/first-word" matching logic would transfer: it
doesn't, because there's no shared word between `"google"` and `"pub/sub"`
to key off of. The port instead checks direct text adjacency — for every
punctuation-free candidate `A` and punctuated candidate `B`, if the literal
string `A + " " + B` appears in the (lowercased) prepped JD text, merge them
into one phrase, keeping the max of the two weights. This subsumes the
Python case too (a multi-word `A` ending right before a punctuated `B`
merges the same way) without needing the word-overlap check Python relies
on, since this engine's fragments never overlap at all.

Also ported: `"profile"` added to `RESP_VERBS` (line-leading imperative,
same bucket as `"analyze"`/`"measure"` — a JD's "Profile and optimize
platform performance…" bullet was leaking the bare verb as a phrase).

**NOT ported**: the Python-side `"jahren"` addition to `SOFT_SKILL_STOPLIST`
(German "years" filler, from the same corpus diff). Checked whether it was
worth porting in isolation and it is not: this engine's dynamic-phrase
output for German JDs (e.g. `job_desc_sherawerkstofftechnologiegmb.txt`) is
already dominated by a much larger, pre-existing noise surface (raw
scraper metadata like `www.arbeitnow.com/jobs/companies/shera` and
timestamps, plus dozens of un-stoplisted German prose words) — the
284-phrase DF≥5 gap flagged back in the Python session and deliberately
left as an out-of-scope, separate initiative pending explicit direction.
Adding one German filler word to a candidate list this noisy wouldn't be
a meaningful fix on its own.

Corpus-wide diff (all `job_desc_*.txt` at the repo root, before/after via
`git stash`): 37 files changed, all consolidations of the same
fragment-into-one-phrase shape (`"top secret/sensitive"`,
`"red hat enterprise linux/se"`, `"cloud serverless components/managed"`,
etc.) — no new noise introduced, verified by inspecting every changed file
in the diff output rather than sampling.

---

### 3.21 2026-08-02 sync: a fourteenth real-world JD (Sezzle) — most of the
Python-side marketing-jargon fixes need no porting at all

Same round as §3.20's Google Pub/Sub fix; a candidate flagged that
`job_desc_sezzle.txt` (a VP Eng Infra/SRE role, heavy on fintech-compliance
and culture-values prose) scored 47.1% on the Python engine mostly from
noise, not genuine gaps. The Python fix (that repo's commit `2939c1c`)
stoplisted eleven items: `frontend`, `version control`, `incident` (bare),
`finance`, and six marketing/business-jargon phrases (`risk-taking`,
`game-changing`, `ai-boosted`, `audit-readiness`, `build-vs-buy`,
`high-severity`), plus curated two real AWS services and `multi-az`.

Checked each of the eleven against this engine one at a time — with an
isolated-sentence harness test per item, not assumed from symmetry — and
**seven needed no porting**:

- `risk-taking`, `ai-boosted`, `audit-readiness`, `build-vs-buy`,
  `high-severity`, `game-changing`: all six are all-lowercase hyphenated
  adjective phrases in the JD's prose. This engine's proper-noun run
  requires a capitalized first letter, and its punctuated-token regex
  (`[./#+]`, no hyphen) doesn't treat hyphens as a valid mid-token
  separator either — so none of the six can ever form as a dynamic-phrase
  candidate here at all, structurally, regardless of stoplisting. Verified
  empirically: isolated sentences containing each phrase produce zero
  candidates.
- `frontend` (bare): never surfaces either, for an unrelated reason — this
  engine's Title-Case scan loop starts at the SECOND word of every line
  (`for (let i = 1; ...)`), so a stack-section header naming its own first
  word (`"Frontend: Typescript - React and React Native"`) is structurally
  invisible to it.
- `version control`: already covered — this app's `KEYWORD_DB` has
  `"git": ["git", "version control"]` as an alias (the Python engine's
  `"git"` canonical doesn't have that alias, which is why Python needed the
  stoplist entry and this engine doesn't).

**Four needed porting, and two of them in a different shape than Python's
fix**: `finance` and `partnerships/sponsorships` port 1:1 (same
department-name and business-jargon noise, both capturable by this
engine's sources same as Python's). But the on-call/incident and
multi-az/multi-region double-counts fragment completely differently here:
Python's punctuated-token regex includes hyphen as part of the leading
word, capturing the full `"on-call/incident"` and (via §3.20's merge fix)
`"multi-az/multi-region"`; this engine's regex does NOT treat hyphen as
part of a token, so the leading hyphenated half is dropped entirely —
producing the bare fragments `"call/incident"` and `"az/multi"` instead.
Confirmed against the actual full JD (not an isolated snippet — an
isolated one-line test produces a differently-shaped `"multi-az/multi-
region posture"`, proving the fragmentation is context-sensitive enough
that only the real JD's output can be trusted). Porting bare `"incident"`
the way Python did wouldn't have worked here either: Python's fix relies on
the curated-padded-with-filler double-count rule (`on-call` curated +
`incident` filler), but this engine's fragment is `"call/incident"` —
`"call"` was never itself curated, so that rule can't reach it. Both
fragments are stoplisted as literal exact strings instead, same bucket as
the already-stoplisted `"shell/power"`.

NOT ported — out of scope, a separate and much larger pre-existing noise
surface specific to this JD's own fragmentation, unrelated to what the
Python round fixed: `"canary/blue"` (garbled fragment of the already-
curated-and-matched `"canary/blue-green"`), `"slos/error"` and
`"dss/soc2"` (same garbled-cross-punctuation family), `"devops & cloud"`
and `"languages"` (stack-section headers, same bucket as `"frontend"`
above but a different root cause), plus generic single-word leaks
(`"control"`, `"source"`, `"built"`, `"many"`, `"despite"`). None of these
were part of the Python fix being ported, and chasing them now would be
the same scope-creep risk flagged and deliberately deferred for the
German-JD noise surface in §3.20.

Corpus-wide diff (all `job_desc_*.txt`, before/after via `git stash`): 3
files changed (`job_desc_sezzle.txt` plus two others where bare `"finance"`
also correctly drops as the same department/industry-vertical noise), 0
additions, 6 clean removals.

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
  is (§2.2 was tuned against 673 real JDs); it is a reasonable first pass,
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
- Future work: (a) re-validate the JS port against the full 673-JD corpus and
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
