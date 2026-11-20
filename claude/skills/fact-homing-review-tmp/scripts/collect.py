#!/usr/bin/env python3
"""Copy a finished workflow's structured outputs from its transcripts into the run folder.

usage: collect.py detect|verify|propose <run-dir> <workflow-run-id>

Agents stay read-only; their answers are already on disk in the session's workflow transcripts.
  detect   collides the raw findings by fact key, routes each and writes findings.json
  verify   applies votes, arbiter rulings and merges to findings.json
  propose  writes proposals.json and the rechecks
Records the run id in scope.json for usage.py and prints a compact summary.
"""

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fh_lib import collide, read_json, route, scope, session_dir, write_json  # noqa: E402
from state import BLIND, merge_into  # noqa: E402

# Which output's correction wins when several agents corrected one finding.
PRECEDENCE = ("arbiter", "holds", "home", "light")
HOME_FIELDS = ("step", "proposed_home")


def structured_output(transcript):
    """The input of the last StructuredOutput call in an agent transcript."""
    last = None
    for line in transcript.read_text().splitlines():
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get("type") != "assistant":
            continue
        for block in rec.get("message", {}).get("content") or []:
            if isinstance(block, dict) and block.get("type") == "tool_use" and block.get("name") == "StructuredOutput":
                last = block.get("input")
    return last


def safe(label):
    return re.sub(r"[^A-Za-z0-9._-]+", "_", label)


def rel(s, path):
    return path.removeprefix(s["repo_path"] + "/").removeprefix("./")


def load_run(run_dir, run_id, kind):
    s = scope(run_dir)
    sess = session_dir(s["session_id"])
    if not sess:
        raise SystemExit(f"session {s['session_id']} not found under ~/.claude/projects")
    record = read_json(sess / "workflows" / f"{run_id}.json")
    if not record:
        raise SystemExit(f"no workflow record {run_id}.json in {sess / 'workflows'}; has it finished?")
    outputs = {}
    for meta_path in sorted((sess / "subagents" / "workflows" / run_id).glob("agent-*.meta.json")):
        label = json.loads(meta_path.read_text()).get("description", "")
        out = structured_output(meta_path.with_name(meta_path.name.replace(".meta.json", ".jsonl")))
        if out is not None:
            outputs[label] = out
    if not any(w["run_id"] == run_id for w in s["workflows"]):
        s["workflows"].append({"run_id": run_id, "kind": kind})
        write_json(run_dir / "scope.json", s)
    result = record.get("result") or {}
    roster = {r["label"]: r for r in result.get("roster", [])}
    for label, out in outputs.items():
        write_json(run_dir / kind / f"{safe(label)}.json", out)
    return s, result, roster, outputs


def collect_detect(run_dir, run_id):
    s, result, roster, outputs = load_run(run_dir, run_id, "detect")
    raw = []
    for label, out in outputs.items():
        if f"{label}:rerun" in outputs:
            continue
        agent = roster.get(label, {}).get("agent", label.split(":")[0])
        for f in out.get("findings", []):
            for site in f["sites"]:
                site["file"] = rel(s, site["file"])
            raw.append({**f, "agent": agent})
    findings = collide(raw)
    for f in findings:
        f["route"] = route(f, BLIND)
        f["verdict"] = "UNVERIFIED"
    write_json(run_dir / "findings.json", findings)
    routes = {r: sum(f["route"] == r for f in findings) for r in ("light", "strong")}
    print(f"{len(raw)} raw findings from {len(outputs)} agents collided into {len(findings)}: "
          f"{routes['strong']} strong, {routes['light']} light")


def angle_of(label):
    if label.startswith("arbiter:"):
        return "arbiter"
    return "light" if label.endswith(":light") else label.split(":")[2]


def collect_verify(run_dir, run_id):
    s, result, roster, outputs = load_run(run_dir, run_id, "verify")
    findings = read_json(run_dir / "findings.json", [])
    by_id = {f["id"]: f for f in findings}
    for row in result.get("findings", []):
        f = by_id[row["id"]]
        votes = []
        for label in row["labels"]:
            out = outputs.get(label)
            if out is None:
                continue
            votes.append({"angle": angle_of(label), "model": roster.get(label, {}).get("model", "?"),
                          "verdict": out["verdict"], "notes": out["notes"], "question": out.get("question", ""),
                          "corrected": out.get("corrected")})
        votes.sort(key=lambda v: PRECEDENCE.index(v["angle"]))
        # Refuters drop the sites they cannot find at HEAD and add the ones the detector missed, so once any
        # vote returns a list, the union of their lists replaces the detector's.
        seen, sites = set(), []
        for v in votes:
            c = v.pop("corrected") or {}
            for site in c.get("sites", []):
                site["file"] = rel(s, site["file"])
                if (site["file"], site["line"]) not in seen:
                    seen.add((site["file"], site["line"]))
                    sites.append(site)
            if v is votes[0]:
                f["fact"] = c.get("fact", f["fact"])
                f.update({k: c[k] for k in ("tie", "scope") if k in c})
            if v["angle"] in ("home", "arbiter"):
                f.update({k: c[k] for k in HOME_FIELDS if k in c})
        if sites:
            f["sites"] = sites
        f["votes"] = votes
        f["verdict"] = row["verdict"]
        f["question"] = f.get("question") or next((v["question"] for v in votes if v["question"]), "")
        arb = next((v for v in votes if v["angle"] == "arbiter"), None)
        if arb:
            f["arbitrated"] = f"opus arbiter: {arb['notes']}"
    for m in result.get("merges", []):
        keep = merge_into(findings, m["keep"], m["merge"])
        keep["merge_why"] = m["why"]
    write_json(run_dir / "findings.json", findings)
    counts = {}
    for f in findings:
        counts[f["verdict"]] = counts.get(f["verdict"], 0) + 1
    print(f"{len(findings)} findings: " + ", ".join(f"{v} {k}" for k, v in sorted(counts.items())))
    escalated = sum(1 for r in result.get("findings", []) if any(lb.endswith(":light") for lb in r["labels"])
                    and any(not lb.endswith(":light") and lb.startswith("verify:") for lb in r["labels"]))
    arbitrated = sum(1 for r in result.get("findings", []) if any(lb.startswith("arbiter:") for lb in r["labels"]))
    print(f"{escalated} escalated from light to strong, {arbitrated} arbitrated, {len(result.get('merges', []))} merges")


def collect_propose(run_dir, run_id):
    s, result, roster, outputs = load_run(run_dir, run_id, "propose")
    proposals = read_json(run_dir / "proposals.json", {})
    rechecks = read_json(run_dir / "rechecks.json", {})
    for label in sorted(outputs):  # a retry sorts after its first attempt and wins
        if label.startswith("recheck:"):
            rechecks[label.split(":")[1]] = outputs[label]
        for p in outputs[label].get("proposals", []):
            for site in p["sites"]:
                site["file"] = rel(s, site["file"])
            proposals[p["finding_id"]] = p
    write_json(run_dir / "proposals.json", proposals)
    write_json(run_dir / "rechecks.json", rechecks)
    incomplete = [i for g in result.get("groups", []) for i in g.get("incomplete", [])]
    print(f"{len(proposals)} proposals, {len(rechecks)} rechecks saved"
          + (f"; incomplete after one retry: {', '.join(incomplete)}" if incomplete else ""))


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("detect", "verify", "propose"):
        raise SystemExit(__doc__)
    kind, run_dir, run_id = sys.argv[1], Path(sys.argv[2]).expanduser(), sys.argv[3]
    {"detect": collect_detect, "verify": collect_verify, "propose": collect_propose}[kind](run_dir, run_id)


if __name__ == "__main__":
    main()
