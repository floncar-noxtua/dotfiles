#!/usr/bin/env python3
"""The orchestrator's interface to the run folder. Every answer is saved the moment it is given.

usage:
  state.py plan-detect <run> --subject "<area, no file names>" [--judge-cap 30] [--override agent=model[/effort]]
  state.py plan-verify <run>
  state.py plan-propose <run>
  state.py summary <run>
  state.py show <run> <id> [--full]
  state.py brief <run> <id> --angle holds|home|answer
  state.py set-verdict <run> <id> CONFIRMED|REFUTED|AMBIGUOUS "<what the code showed>"
  state.py merge <run> <keep-id> <id> ...
  state.py clarify <run> <id> "<answer>" [--close] [--adds-site path:line ...]
  state.py rule <run> <id> approve|drop|follow-up|amend [--note "..."] [--ticket "..."] [--edits file.json]
  state.py next <run>

The plan-* commands print a workflow's args as JSON; pass them to the Workflow tool verbatim.
"""

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fh_lib import AGENTS_DIR, SKILL_DIR, file_groups, rank, read_json, scope, write_json  # noqa: E402

JUDGE_CAP = 30
OPEN = {"UNCERTAIN", "SPLIT"}
GONE = {"REFUTED", "MERGED"}
BLIND = ["fh-sweep-code", "fh-sweep-prose", "fh-sweep-declarations"]
# What a refuter sees. The detector's rationale and agents stay out, so the refuter reads the code rather
# than agreeing with an argument; the `holds` angle does not see the proposed home either.
BRIEF_FIELDS = ["id", "fact", "fact_key", "lens", "form", "about", "time", "why", "scope",
                "sites", "home_now", "ends", "tie", "consequence", "exception"]
HOME_FIELDS = ["step", "proposed_home", "recovery_cost"]


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def load(run):
    run = Path(run).expanduser()
    return (run, read_json(run / "findings.json", []), read_json(run / "clarifications.json", {}),
            read_json(run / "proposals.json", {}), read_json(run / "rulings.json", {}))


def find(findings, fid):
    for f in findings:
        if f["id"] == fid:
            return f
    raise SystemExit(f"no finding {fid}")


def proposable(f, clar):
    c = clar.get(f["id"])
    if c and c.get("close"):
        return False
    return f["verdict"] == "CONFIRMED" or (f["verdict"] == "AMBIGUOUS" and c is not None)


def common_args(run, s):
    return {"runDir": str(run), "repo": s["repo_path"], "skill": str(SKILL_DIR), "agents": str(AGENTS_DIR), "base": s["merge_base"]}


def plan_detect(a):
    run = Path(a.run).expanduser()
    s = scope(run)
    s["subject_area"] = a.subject
    clusters = read_json(run / "clusters.json", {"clusters": []})["clusters"]
    judged = clusters[: a.judge_cap]
    s["clusters_judged"], s["clusters_left"] = len(judged), len(clusters) - len(judged)
    overrides = {}
    for o in a.override or []:
        agent, _, spec = o.partition("=")
        model, _, effort = spec.partition("/")
        overrides[agent] = {k: v for k, v in (("model", model), ("effort", effort)) if v}
    s["overrides"] = overrides
    write_json(run / "scope.json", s)
    items = [{"agent": "fh-ssot-judge", "cluster": c["id"]} for c in judged]
    for agent in s["agents"]:
        if agent in s.get("slices", {}):
            items += [{"agent": agent, "slice": p} for p in s["slices"][agent]]
        elif agent in BLIND:
            items.append({"agent": agent})
    print(json.dumps({**common_args(run, s), "subjectArea": a.subject, "items": items, "overrides": overrides}))
    if s["clusters_left"]:
        print(f"note: {s['clusters_left']} clusters beyond the cap of {a.judge_cap} are not judged this run",
              file=sys.stderr)


def plan_verify(a):
    run, findings, *_ = load(a.run)
    s = scope(run)
    if not findings:
        raise SystemExit("no findings.json yet; run collect.py detect first")
    items = [{"id": f["id"], "route": f["route"]} for f in findings]
    print(json.dumps({**common_args(run, s), "items": items, "overrides": s.get("overrides", {})}))


def plan_propose(a):
    run, findings, clar, *_ = load(a.run)
    s = scope(run)
    todo = [f for f in sorted(findings, key=rank) if proposable(f, clar)]
    recheck = [f["id"] for f in todo if clar.get(f["id"], {}).get("adds_sites")]
    print(json.dumps({**common_args(run, s), "groups": file_groups(todo), "recheck": recheck,
                      "overrides": s.get("overrides", {})}))


def summary(a):
    run, findings, clar, props, rulings = load(a.run)
    if not findings:
        raise SystemExit("no findings.json yet; run collect.py detect")
    for f in sorted(findings, key=rank):
        if f["verdict"] in GONE:
            continue
        state = rulings.get(f["id"], {}).get("ruling") or ("clarified" if f["id"] in clar else "")
        print(f"{f['id']}  {f['verdict']:<9} {f['lens']:<11} {f['about']:<10} {f['consequence']:<7} "
              f"{f['route']:<6} sites={len(f['sites']):<3} {state:<9} {f['fact'][:90]}")
    gone = {v: sum(f["verdict"] == v for f in findings) for v in GONE}
    print(f"({gone['REFUTED']} refuted and {gone['MERGED']} merged, not shown)")


def show(a):
    run, findings, clar, props, rulings = load(a.run)
    f = find(findings, a.id)
    print(f"{f['id']} · {f['lens']} · {f['form']} about {f['about']}, {f['time']}{', carries a why' if f.get('why') else ''}"
          f" · {f['consequence']} · {f['scope']} · {f['verdict']} · from {', '.join(f.get('agents', []))}")
    print(f"fact: {f['fact']}")
    print(f"fact_key: {f['fact_key']}")
    print(f"home now: {f['home_now']} ({f['ends']}, {f['tie']})"
          + (f"; rests on exception {f['exception']}" if f.get("exception") else ""))
    print(f"proposed: {f['step']} -> {f['proposed_home']}; recovery cost {f.get('recovery_cost', 'n/a')}")
    print("sites:")
    for x in f["sites"]:
        print(f"  {x['role']:<8} {x['file']}:{x['line']}  {x.get('quote', '')[:150]}")
    print(f"rationale: {f['rationale']}")
    if f.get("question"):
        print(f"question: {f['question']}")
    if f["id"] in clar:
        c = clar[f["id"]]
        print(f"clarification{' (closed)' if c.get('close') else ''}: {c['answer']}"
              + (f"; adds {', '.join(c['adds_sites'])}" if c.get("adds_sites") else ""))
    if f.get("arbitrated"):
        print(f"arbitrated: {f['arbitrated']}")
    if f.get("merged_from"):
        print(f"merged from: {', '.join(f['merged_from'])}")
    if a.full:
        for v in f.get("votes", []):
            print(f"vote {v['angle']} ({v['model']}): {v['verdict']} - {v['notes']}")
    p = props.get(f["id"])
    if p:
        print(f"proposal: {p['step']} -> {p['home']}; tie after: {p['tie_after']}")
        print(f"  {p['summary']}")
        for e in p["edits"]:
            print(f"  edit {e['action']} {e['file']}\n    anchor: {e['anchor'][:300]}\n    content: {e['content'][:600]}")
        if p.get("pointer"):
            print(f"  pointer: {p['pointer']}")
        if p.get("record"):
            print(f"  commit body: {p['record']}")
        if p.get("doubts"):
            print(f"  doubts: {p['doubts']}")
    if f["id"] in rulings:
        print(f"ruling: {json.dumps(rulings[f['id']])}")


def brief(a):
    _, findings, clar, *_ = load(a.run)
    f = find(findings, a.id)
    keep = BRIEF_FIELDS + (HOME_FIELDS if a.angle in ("home", "answer") else [])
    out = {k: f[k] for k in keep if k in f}
    if a.angle == "answer":
        out["human_answer"] = clar[a.id]["answer"]
        out["added_sites"] = clar[a.id].get("adds_sites", [])
    print(json.dumps(out, indent=1, ensure_ascii=False))


def set_verdict(a):
    run, findings, *_ = load(a.run)
    f = find(findings, a.id)
    f["verdict"], f["arbitrated"] = a.verdict, f"orchestrator: {a.note} ({now()})"
    write_json(run / "findings.json", findings)
    print(f"{a.id} -> {a.verdict}")


def merge_into(findings, keep_id, others):
    keep = find(findings, keep_id)
    seen = {(x["file"], x["line"]) for x in keep["sites"]}
    for fid in others:
        other = find(findings, fid)
        keep["sites"] += [x for x in other["sites"] if (x["file"], x["line"]) not in seen]
        seen.update((x["file"], x["line"]) for x in other["sites"])
        keep["agents"] = sorted(set(keep.get("agents", [])) | set(other.get("agents", [])))
        keep.setdefault("merged_from", []).append(fid)
        other["verdict"], other["merged_into"] = "MERGED", keep_id
    return keep


def merge(a):
    run, findings, *_ = load(a.run)
    keep = merge_into(findings, a.keep, a.others)
    write_json(run / "findings.json", findings)
    print(f"{', '.join(a.others)} merged into {a.keep}: {len(keep['sites'])} sites")


def clarify(a):
    run, findings, clar, *_ = load(a.run)
    find(findings, a.id)
    clar[a.id] = {"answer": a.answer, "close": a.close, "adds_sites": a.adds_site or [], "at": now()}
    write_json(run / "clarifications.json", clar)
    print(f"{a.id} clarified" + (" and closed" if a.close else "")
          + (f"; {len(a.adds_site)} new sites will be rechecked" if a.adds_site else ""))


def rule(a):
    run, findings, clar, props, rulings = load(a.run)
    find(findings, a.id)
    if a.ruling == "amend" and not (a.note or a.edits):
        raise SystemExit("amend needs --note or --edits with the human's wording")
    entry = {"ruling": a.ruling, "at": now()}
    if a.note:
        entry["note"] = a.note
    if a.ticket:
        entry["ticket"] = a.ticket
    if a.edits:
        entry["edits"] = json.loads(Path(a.edits).read_text())
    rulings[a.id] = entry
    write_json(run / "rulings.json", rulings)
    print(f"{a.id}: {a.ruling}")


def next_step(a):
    run = Path(a.run).expanduser()
    s = scope(run)
    _, findings, clar, props, rulings = load(run)
    kinds = {w["kind"] for w in s["workflows"]}

    def say(phase, what):
        print(f"next: phase {phase} - {what}")

    if not (run / "clusters.json").exists():
        return say(1, "run index.py, then slice.py")
    if "detect" not in kinds:
        return say(2, "state.py plan-detect, the detect workflow, then collect.py detect")
    if "verify" not in kinds:
        return say(3, "state.py plan-verify, the verify workflow, then collect.py verify")
    open_ = [f["id"] for f in findings if f["verdict"] in OPEN]
    if open_:
        return say(4, f"arbiter left these open, settle them by reading the sites: {', '.join(open_)}")
    unclear = [f["id"] for f in sorted(findings, key=rank) if f["verdict"] == "AMBIGUOUS" and f["id"] not in clar]
    if unclear:
        return say(5, f"clarify {', '.join(unclear)}")
    todo = [f for f in sorted(findings, key=rank) if proposable(f, clar)]
    if todo and "propose" not in kinds:
        return say(6, "state.py plan-propose, the propose workflow, then collect.py propose")
    unruled = [f["id"] for f in todo if f["id"] not in rulings]
    if unruled:
        return say(7, f"rule {', '.join(unruled)}")
    if not (run / "record.md").exists():
        return say(8, "commit body and PR description into record.md")
    if not (run / "verdict.md").exists():
        return say(9, "write verdict.md, then usage.py and render.py")
    if not (run / "review.md").exists():
        return say(9, "run usage.py, then render.py")
    say(10, f"{s['mode']} mode: " + ("apply changes.md with fh-scribe" if s["mode"] == "author"
                                    else "post review.md up to the marker after a yes"))


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    def cmd(name, fn, *extra):
        p = sub.add_parser(name)
        p.add_argument("run")
        for args, kw in extra:
            p.add_argument(*args, **kw)
        p.set_defaults(fn=fn)

    cmd("plan-detect", plan_detect, (["--subject"], {"required": True}),
        (["--judge-cap"], {"type": int, "default": JUDGE_CAP}), (["--override"], {"action": "append"}))
    for name, fn in (("plan-verify", plan_verify), ("plan-propose", plan_propose),
                     ("summary", summary), ("next", next_step)):
        cmd(name, fn)
    cmd("show", show, (["id"], {}), (["--full"], {"action": "store_true"}))
    cmd("brief", brief, (["id"], {}), (["--angle"], {"choices": ["holds", "home", "answer"], "required": True}))
    cmd("set-verdict", set_verdict, (["id"], {}),
        (["verdict"], {"choices": ["CONFIRMED", "REFUTED", "AMBIGUOUS"]}), (["note"], {}))
    cmd("merge", merge, (["keep"], {}), (["others"], {"nargs": "+"}))
    cmd("clarify", clarify, (["id"], {}), (["answer"], {}), (["--close"], {"action": "store_true"}),
        (["--adds-site"], {"action": "append"}))
    cmd("rule", rule, (["id"], {}), (["ruling"], {"choices": ["approve", "drop", "follow-up", "amend"]}),
        (["--note"], {}), (["--ticket"], {}), (["--edits"], {}))
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
