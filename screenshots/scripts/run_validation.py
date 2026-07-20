#!/usr/bin/env python3
"""Extracts the pure-JS scoring core from app/index.html and runs it against
the built-in SAMPLE_JD/SAMPLE_RZ fixtures in Node — the same reproducible
validation command documented in RESEARCH.md §3. Prints TOTAL and the
missing-keyword list, which is what 04_validation_terminal.png shows.

Usage: python3 run_validation.py   (from screenshots/scripts/, or anywhere —
paths below are relative to this file, not the cwd)
"""
import re
import subprocess
from pathlib import Path

repo = Path(__file__).resolve().parents[2]  # my-kanz/
html = (repo / "app" / "index.html").read_text()
js = re.search(r"<script>\n(.*)</script>", html, re.S).group(1)
core = js.split("/* =========================== UI wiring")[0]
sm = re.search(r"const SAMPLE_JD = `(.*?)`;\n\nconst SAMPLE_RZ = `(.*?)`;", js, re.S)

test_js = core + f"""
const r = analyze(`{sm.group(1)}`, `{sm.group(2)}`);
console.log("TOTAL:", (r.total*100).toFixed(1)+"%");
console.log("missing:", r.kw.miss.map(x=>x[0]).join(", "));
"""
tmp = Path("/tmp/kanzmatch_test.js")
tmp.write_text(test_js)
subprocess.run(["node", str(tmp)], check=True)
