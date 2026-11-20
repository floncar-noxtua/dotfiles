#!/usr/bin/env python3
"""Phase 9: turn the rulings into review.md, and the approved edits into changes.md for fh-scribe.

usage: render.py <run-dir>

Also writes review.qf: one `path:line: message` line per site of every kept finding, in review order, with
absolute paths, for `nvim -q review.qf`. Reads verdict.md and record.md (written by the orchestrator),
findings, proposals, clarifications, rechecks, rulings and usage. Dropped findings never appear. Everything
above the <!-- review-end --> marker is the review; the header, method and usage below it stay out of a PR
comment.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fh_lib import rank, read_json, scope, write_json  # noqa: E402

MARKER = "<!-- review-end -->"
LENS = {"ssot": "single source", "prose": "comment", "name": "name", "declaration": "declaration", "test": "test",
        "todo": "TODO", "claim": "claim", "procedure": "procedure", "doc": "document"}


def fence(text, lang=""):
    ticks = "````" if "```" in text else "```"
    return f"{ticks}{lang}\n{text.rstrip()}\n{ticks}"


def num(n):
    return f"{n:,}"


def main():
    run = Path(sys.argv[1]).expanduser()
    s = scope(run)
    findings = {f["id"]: f for f in read_json(run / "findings.json", [])}
    props = read_json(run / "proposals.json", {})
    clar = read_json(run / "clarifications.json", {})
    checks = read_json(run / "rechecks.json", {})
    rulings = read_json(run / "rulings.json", {})
    usage = read_json(run / "usage.json")
    verdict = (run / "verdict.md").read_text().strip() if (run / "verdict.md").exists() else "_No verdict written._"
    record = (run / "record.md").read_text().strip() if (run / "record.md").exists() else "_Not redrafted._"

    def ruled(*kinds):
        return sorted((findings[i] for i, r in rulings.items() if r["ruling"] in kinds and i in findings), key=rank)

    kept, follow = ruled("approve", "amend"), ruled("follow-up")
    changes, out = [], []

    def block(f, compact=False):
        fid, p, r = f["id"], props.get(f["id"], {}), rulings[f["id"]]
        step = p.get("step", f["step"])
        lines = [f"### {fid} · {LENS[f['lens']]} · {f['consequence']} · {step}", "",
                 f"**Fact.** {f['fact']} ({f['form']} about the {f['about']}, {f['time']})", "",
                 f"**Now.** {f['home_now']}: {f['tie']}"
                 + (f", by the repo exception {f['exception']}" if f.get("exception") else ""), "",
                 f"**After.** {p.get('home', f['proposed_home'])}" + (f": {p['tie_after']}" if p.get("tie_after") else ""), ""]
        if not compact:
            lines += [f"**Why.** {f['rationale']}", ""]
        if fid in clar:
            lines += [f"**Clarified.** {clar[fid]['answer']}", ""]
        if fid in checks:
            lines += [f"**Rechecked.** {checks[fid]['verdict']}: {checks[fid]['notes']}", ""]
        if r["ruling"] == "amend" and r.get("note"):
            lines += [f"**Amended.** {r['note']}", ""]
        if p.get("record"):
            lines += ["**Commit body.**", "", fence(p["record"]), ""]
        lines += ["| Role | Site | Now |", "|---|---|---|"]
        quotes = {(x["file"], x["line"]): x.get("quote", "") for x in f["sites"]}
        for x in p.get("sites") or f["sites"]:
            q = quotes.get((x["file"], x["line"]), "")[:110].replace("|", "\\|")
            code = f"`` {q} ``" if "`" in q else f"`{q}`"
            lines.append(f"| {x['role']} | `{x['file']}:{x['line']}` | {code if q else ''} |")
        lines.append("")
        if r["ruling"] == "amend" and not r.get("edits"):
            return lines + ["**Edits.** Left out of the change list: the amendment supersedes the proposed edits.", ""]
        for e in r.get("edits") or p.get("edits", []):
            changes.append({"n": len(changes) + 1, "finding": fid, **e})
            lines.append(f"{len(changes)}. `{e['file']}`: {e['action'].replace('_', ' ')}")
            if e.get("anchor"):
                lines += ["", "   Anchor:", "", "   " + fence(e["anchor"]).replace("\n", "\n   ")]
            if e.get("content"):
                lines += ["", "   New text:", "", "   " + fence(e["content"]).replace("\n", "\n   ")]
            lines.append("")
        return lines

    out += ["## Verdict", "", verdict, "", "## Commit body and PR description", "", record, ""]
    main_ = [f for f in kept if f["lens"] != "procedure" and f["consequence"] != "hygiene"]
    procs = [f for f in kept if f["lens"] == "procedure"]
    minor = [f for f in kept if f["lens"] != "procedure" and f["consequence"] == "hygiene"]
    for title, fs, compact in (("Changes", main_, False), ("Procedures", procs, False), ("Minor items", minor, True)):
        if fs:
            out += [f"## {title}", ""]
            for f in fs:
                out += block(f, compact)
    if follow:
        out += ["## Follow-ups", ""]
        for f in follow:
            r, p = rulings[f["id"]], props.get(f["id"], {})
            src = next((x for x in f["sites"] if x["role"] == "source"), f["sites"][0])
            out += [f"- **{f['id']}** {f['fact']}",
                    f"  - Ticket: {r.get('ticket') or p.get('ticket') or r.get('note') or f['rationale']}",
                    f"  - Pointer: {p.get('pointer') or 'a `TODO` naming the ticket'} at `{src['file']}:{src['line']}`", ""]

    out += [MARKER, "", "---", "",
            f"# PR {s['pr'] or '(none)'}: {s['title']}", "",
            "| | |", "|---|---|",
            f"| Mode | {s['mode']} |",
            f"| Link | {s['url'] or '-'} |",
            f"| Branch | `{s['branch']}` into `{s['base']}` at `{s['head_sha'][:10]}` |",
            f"| Date | {s['started_at'][:10]} |",
            "| Standard | `docs/fact-homing.md` |",
            f"| Scope | {s['stats']['files']} files, +{s['stats']['added_lines']} -{s['stats']['removed_lines']}, {s['size']} |",
            ""]

    all_f = list(findings.values())
    counts, ruled_n = {}, {}
    for f in all_f:
        counts[f["verdict"]] = counts.get(f["verdict"], 0) + 1
    for r in rulings.values():
        ruled_n[r["ruling"]] = ruled_n.get(r["ruling"], 0) + 1
    escalated = [f["id"] for f in all_f if {"light", "holds"} <= {v["angle"] for v in f.get("votes", [])}]
    out += ["## Method", "",
            f"- Clusters judged: {s.get('clusters_judged', 0)}"
            + (f", {s['clusters_left']} left beyond the cap" if s.get("clusters_left") else "") + ".",
            f"- Routes: {sum(f.get('route') == 'strong' for f in all_f)} strong, {sum(f.get('route') == 'light' for f in all_f)} light; "
            f"escalated from light: {', '.join(escalated) or 'none'}.",
            f"- Verdicts: {', '.join(f'{v} {k}' for k, v in sorted(counts.items()))}.",
            f"- Arbitrated: {', '.join(f['id'] for f in all_f if f.get('arbitrated')) or 'none'}.",
            f"- Merged as one fact: {', '.join(f'{f['id']} into {f['merged_into']}' for f in all_f if f.get('merged_into')) or 'none'}.",
            f"- Clarified by the human: {', '.join(sorted(clar)) or 'none'}; rechecked: {', '.join(sorted(checks)) or 'none'}.",
            f"- Rulings: {', '.join(f'{v} {k}' for k, v in sorted(ruled_n.items())) or 'none'}.", ""]

    out += ["## Token usage", ""]
    if usage:
        out += ["| Agent | Phase | Model | Effort | Input | Cache write | Cache read | Output | Total |",
                "|---|---|---|---|---:|---:|---:|---:|---:|"]
        for r in usage["rows"]:
            out.append(f"| {r['label']} | {r['phase']} | {r['model']} | {r['effort']} | {num(r['input'])} | "
                       f"{num(r['cache_write'])} | {num(r['cache_read'])} | {num(r['output'])} | {num(r['total'])} |")
        t = usage["total"]
        out.append(f"| **Total** | | | | {num(t['input'])} | {num(t['cache_write'])} | {num(t['cache_read'])} | "
                   f"{num(t['output'])} | **{num(t['total'])}** |")
        out += ["", "| Agent | Count | Total |", "|---|---:|---:|"]
        for k, v in sorted(usage["by_agent"].items(), key=lambda kv: -kv[1]["total"]):
            out.append(f"| {k} | {v['count']} | {num(v['total'])} |")
        out += ["", f"- Reruns: {', '.join(usage['reruns']) or 'none'}."] + [f"- {n}" for n in usage.get("notes", [])]
    else:
        out.append("_Not reported: run usage.py before render.py._")

    (run / "review.md").write_text("\n".join(out).rstrip() + "\n")
    root = Path(s["repo_path"])
    qf = [f"{root / x['file']}:{x['line']}: {f['id']} {LENS[f['lens']]} · {x['role']} · {f['fact']}".replace("\n", " ")
          for f in [*main_, *procs, *minor, *follow] for x in f["sites"]]
    (run / "review.qf").write_text("".join(q + "\n" for q in qf))
    write_json(run / "changes.json", changes)
    scribe = [f"# Change list for {s['repo']} at {s['head_sha'][:10]}", "",
              "Apply each entry verbatim. Anchor is existing text; New text replaces or joins it per the action.", ""]
    for c in changes:
        scribe += [f"## {c['n']}. {c['finding']} · `{c['file']}` · {c['action']}", ""]
        if c.get("anchor"):
            scribe += ["Anchor:", "", fence(c["anchor"]), ""]
        if c.get("content"):
            scribe += ["New text:", "", fence(c["content"]), ""]
    (run / "changes.md").write_text("\n".join(scribe).rstrip() + "\n")
    print(f"review.md: {len(main_)} changes, {len(follow)} follow-ups, {len(procs)} procedures, {len(minor)} minor; "
          f"changes.md: {len(changes)} edits; review.qf: {len(qf)} sites")


if __name__ == "__main__":
    main()
