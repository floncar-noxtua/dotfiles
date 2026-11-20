#!/usr/bin/env python3
"""Token usage per agent and in total, from the transcripts Claude Code wrote. Never estimated.

usage: usage.py <run-dir>

Reads, from ~/.claude/projects/: the main session transcript from scope.started_at on (the
orchestrator), every plain subagent of the session started since then, and the agents of each
workflow in scope.workflows, whose saved result carries the model and effort the script passed.
A message's usage is repeated once per content block, so each message id is counted once.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fh_lib import read_json, scope, session_dir, session_transcript, write_json  # noqa: E402

FIELDS = ("input", "cache_write", "cache_read", "output")
PHASE_OF_TYPE = {"fh-record-writer": "8", "fh-scribe": "10"}
PHASE_OF_WORKFLOW = {"Detect": "2", "Verify": "3", "Arbitrate": "3", "Merge": "3", "Recheck": "6", "Propose": "6"}


def tally(path, since=None):
    """Sum usage per message id. A message is written once per content block and only the last
    record carries the final output count, so each field takes its highest value per message."""
    per_msg, models, first = {}, set(), None
    for line in path.read_text().splitlines():
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get("type") != "assistant":
            continue
        ts = rec.get("timestamp", "")
        if since and ts < since:
            continue
        msg = rec.get("message", {})
        mid, u = msg.get("id"), msg.get("usage")
        if not mid or not u:
            continue
        first = first or ts
        cur = per_msg.setdefault(mid, dict.fromkeys(FIELDS, 0))
        for field, key in zip(FIELDS, ("input_tokens", "cache_creation_input_tokens",
                                       "cache_read_input_tokens", "output_tokens")):
            cur[field] = max(cur[field], u.get(key, 0) or 0)
        if msg.get("model"):
            models.add(msg["model"])
    totals = {f: sum(m[f] for m in per_msg.values()) for f in FIELDS}
    totals["total"] = sum(totals.values())
    return totals, ", ".join(sorted(models)) or "not reported", first


def main():
    run_dir = Path(sys.argv[1]).expanduser()
    s = scope(run_dir)
    sess, main_log = session_dir(s["session_id"]), session_transcript(s["session_id"])
    if not main_log:
        raise SystemExit(f"session transcript for {s['session_id']} not found")
    since = s["started_at"]
    rows, notes = [], []

    t, model, _ = tally(main_log, since)
    rows.append({"label": "orchestrator", "agent": "orchestrator", "phase": "0-10", "model": model,
                 "effort": s.get("orchestrator_effort") or "not reported", **t})

    for w in s.get("workflows", []):
        record = read_json(sess / "workflows" / f"{w['run_id']}.json", {}) or {}
        roster = {r["label"]: r for r in (record.get("result") or {}).get("roster", [])}
        for meta_path in sorted((sess / "subagents" / "workflows" / w["run_id"]).glob("agent-*.meta.json")):
            meta = json.loads(meta_path.read_text())
            label = meta.get("description", meta_path.stem)
            t, model, _ = tally(meta_path.with_name(meta_path.name.replace(".meta.json", ".jsonl")))
            r = roster.get(label, {})
            rows.append({"label": label, "agent": r.get("agent", meta.get("agentType", "?")),
                         "phase": PHASE_OF_WORKFLOW.get(meta.get("workflowPhase") or r.get("phase"), "?"),
                         "model": model, "effort": r.get("effort", "not reported"), **t})
        if not roster:
            notes.append(f"workflow {w['run_id']}: no saved roster, effort not reported")

    for meta_path in sorted((sess / "subagents").glob("agent-*.meta.json")) if sess else []:
        meta = json.loads(meta_path.read_text())
        t, model, first = tally(meta_path.with_name(meta_path.name.replace(".meta.json", ".jsonl")))
        if not first or first < since:
            continue
        kind = meta.get("agentType", "?")
        rows.append({"label": meta.get("description", kind), "agent": kind, "phase": PHASE_OF_TYPE.get(kind, "-"),
                     "model": model, "effort": "default", **t})

    total = {f: sum(r[f] for r in rows) for f in (*FIELDS, "total")}
    by_agent = {}
    for r in rows:
        b = by_agent.setdefault(r["agent"], {"count": 0, **dict.fromkeys((*FIELDS, "total"), 0)})
        b["count"] += 1
        for f in (*FIELDS, "total"):
            b[f] += r[f]
    reruns = [r["label"] for r in rows if r["label"].endswith((":rerun", ":retry"))]
    write_json(run_dir / "usage.json", {"rows": rows, "by_agent": by_agent, "total": total,
                                        "reruns": reruns, "notes": notes})
    top = max(by_agent.items(), key=lambda kv: kv[1]["total"])
    print(f"{len(rows)} rows, {total['total']:,} tokens in total; most: {top[0]} ({top[1]['total']:,})")


if __name__ == "__main__":
    main()
