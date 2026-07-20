# SUBMISSION.md — Kanz AI Training Hackathon package

Submit at **https://try.ka.nz/hack/submit**. This file maps every requirement from
https://try.ka.nz/hack/submit/instructions to a ready asset. Word counts for the
description fields are verified (see the check command at the bottom).

## Checklist (from the official instructions)

| Requirement | Status / asset |
|---|---|
| Project details form | copy the six fields below |
| Demo video — MP4, 1–3 min, 50–200 MB, landscape 16:9 | record per `VIDEO_SCRIPT.md` |
| Video must show (web app): **AI responding with feature switching** | script covers it: 3 AI tabs, live streaming output |
| Prohibited in video: slides, planned-work talk, third-party demos, bare links | script contains none of these |
| Screenshots: real app UI / terminal / IDE only | capture: score screen, chips, AI panel streaming, `RESEARCH.md` open in editor |
| Resume: **PDF only** (.docx and images are skipped) | export `abdoul_aw_resume_open` as PDF before uploading |
| Team submissions: identical team names, copy-pasted | solo submission — n/a |

---

## Project description fields (paste as-is, edit freely)

### Problem — min 40 words (this draft: ~75)

Job seekers are rejected by automated screening before any human reads their
resume, and they never learn why. Existing resume-checking tools charge monthly
subscriptions, run every resume through server-side AI they must pay for, and
require uploading sensitive personal documents to someone else's database. For
millions of candidates — including Kanz's 1.2 million job seekers — that means
paying for opaque feedback, or applying blind and losing opportunities to a
keyword filter they could have satisfied honestly.

### Solution — min 40 words (this draft: ~80)

KanzMatch is a single-file web app that scores any resume against any job
description instantly and entirely inside the browser — zero servers, zero cost,
zero data leaving the device. A corpus-tuned engine rates keyword coverage,
structure, and experience, then shows exactly which skills matched and which are
missing. An optional AI coach, powered by Claude with the user's own API key,
rewrites the summary, builds a thirty-day gap-closing plan, and drafts cover-letter
openers — streamed live, for fractions of a cent.

### How I built it — min 40 words (this draft: ~85)

I ported the architecture of my own 2,300-line Python ATS checker — previously
tuned against 673 real job descriptions using document-frequency noise analysis —
into dependency-free JavaScript inside one HTML file: a 181-term curated skill
dictionary with aliases, dynamic phrase mining with weighted proper-noun
down-ranking, and a harmonic-mean keyword score combined with structure and
experience checks. The AI coach calls Anthropic's Messages API directly from the
browser with streaming responses. I validated with positive and negative control
resumes, fixing extraction noise until every reported gap was genuine.

### Who benefits — min 20 words (this draft: ~45)

Every job seeker screened by automated systems — especially early-career and
budget-constrained candidates who cannot afford subscription resume tools.
Career coaches and hiring platforms like Kanz also benefit: the tool costs
nothing to host at any scale and keeps candidate resumes completely private.

### Future vision — min 20 words (this draft: ~45)

Arabic-language job-description support for Kanz's home market, client-side PDF
parsing, corpus re-validation against hundreds of postings, and an embeddable
widget so any hiring platform can offer instant, private, zero-marginal-cost
resume feedback to millions of candidates without running a single server.

### Professional bio — min 20 words (this draft: ~40)

Senior Site Reliability / DevOps engineer with deep AWS, Kubernetes, Terraform,
and observability experience, building automation that removes toil. I create
open tooling for the job-search process itself — resume tailoring, ATS scoring,
and job-board scrapers — and applied that work to this hackathon.

---

## Screenshot shot-list (take these, in order)

1. Full app, light mode, samples loaded, before Analyze.
2. Score screen after Analyze: 88% hero number, three bars, verdict.
3. Matched vs missing chip panels (the forensic payoff).
4. AI coach mid-stream on "Gap-closing plan" (text visibly incomplete = live).
5. Dark mode of the same screen (shows deliberate theming).
6. Terminal running the headless validation command from RESEARCH.md §3.

## Verify the word minimums

```bash
python3 - <<'EOF'
import re
t = open('SUBMISSION.md').read()
for name, minw in [("Problem",40),("Solution",40),("How I built it",40),
                   ("Who benefits",20),("Future vision",20),("Professional bio",20)]:
    m = re.search(rf"### {re.escape(name)}.*?\n\n(.*?)\n\n###?", t, re.S) or \
        re.search(rf"### {re.escape(name)}.*?\n\n(.*?)\n\n---", t, re.S)
    n = len(m.group(1).split())
    print(f"{name}: {n} words (min {minw}) {'OK' if n>=minw else 'TOO SHORT'}")
EOF
```
