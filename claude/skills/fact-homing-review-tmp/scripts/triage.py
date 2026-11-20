#!/usr/bin/env python3
"""Phase 0: create the run folder, record the scope and pick the agents. Reads no file contents.

usage: triage.py (--pr N | --base REF) --mode author|reviewer

Run from inside the repository, on the PR head. The run folder goes under $FACT_HOMING_RUNS, default
~/.local/state/fact-homing-review/. Prints the folder, the size and the agents.
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fh_lib import (  # noqa: E402
    CI_RE, CONFIG_RE, DOC_RE, RUNS_ROOT, SKILL_RE, TEST_RE, TODO_RE,
    changed_files, git, parse_diff, sh, write_json,
)

SMALL_LINES = 50
LARGE_FILES = 40
DIFF_LENSES = ["fh-prose-at-site", "fh-names", "fh-declarations", "fh-tests", "fh-todos", "fh-docs"]


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--pr", type=int)
    g.add_argument("--base")
    ap.add_argument("--mode", choices=["author", "reviewer"], required=True)
    a = ap.parse_args()

    repo = git(".", "rev-parse", "--show-toplevel").strip()
    name = Path(repo).name
    head_sha = git(repo, "rev-parse", "HEAD").strip()
    branch = git(repo, "branch", "--show-current").strip()

    pr = None
    if a.pr:
        pr = json.loads(sh(["gh", "pr", "view", str(a.pr), "--json",
                            "number,title,body,baseRefName,headRefName,headRefOid,url"], cwd=repo))
        if pr["headRefOid"] != head_sha:
            raise SystemExit(f"HEAD is not the PR head. Check it out first: gh pr checkout {a.pr}")
        base = pr["baseRefName"]
    else:
        base = a.base

    git(repo, "fetch", "--quiet", "origin", base, check=False)
    merge_base = (git(repo, "merge-base", f"origin/{base}", "HEAD", check=False).strip()
                  or git(repo, "merge-base", base, "HEAD").strip())

    key = str(a.pr) if a.pr else re.sub(r"[^A-Za-z0-9._-]+", "-", branch or head_sha[:8])
    run_dir = RUNS_ROOT / f"{name}-{key}"
    if (run_dir / "scope.json").exists():
        raise SystemExit(f"run folder exists: {run_dir}\nresume it, or move it away to start fresh")
    run_dir.mkdir(parents=True, exist_ok=True)

    rng = f"{merge_base}...HEAD"
    files = changed_files(repo, rng)
    parsed = parse_diff(git(repo, "diff", "-U0", rng))
    plus = [(p, body) for p, hunks in parsed.items() for h in hunks for s, _, _, body in h if s == "+"]
    minus = [(p, body) for p, hunks in parsed.items() for h in hunks for s, _, _, body in h if s == "-"]
    paths = [p for _, p in files]

    def count(pred, rows):
        return sum(1 for p, body in rows if pred(p, body))

    stats = {
        "files": len(files),
        "added_lines": len(plus),
        "removed_lines": len(minus),
        "python_files": sum(p.endswith(".py") for p in paths),
        "test_files": sum(bool(TEST_RE.search(p)) for p in paths),
        "doc_files": sum(bool(DOC_RE.search(p)) for p in paths),
        "config_files": sum(bool(CONFIG_RE.search(p)) for p in paths),
        "ci_files": sum(bool(CI_RE.search(p)) for p in paths),
        "skill_files": sum(bool(SKILL_RE.search(p)) for p in paths),
        "added_or_renamed": sum(s in "AR" for s, _ in files),
        "comment_lines": count(lambda p, b: p.endswith(".py") and b.lstrip().startswith("#"), plus + minus),
        "docstring_lines": count(lambda p, b: p.endswith(".py") and ('"""' in b or "'''" in b), plus + minus),
        "definition_lines": count(lambda p, b: p.endswith(".py") and re.match(
            r"\s*(class |def |async def |[A-Z_][A-Z0-9_]*\s*[:=])", b), plus),
        "todo_lines": count(lambda p, b: bool(TODO_RE.search(b)), plus + minus),
    }

    lenses = {
        "fh-prose-at-site": stats["comment_lines"] + stats["docstring_lines"] > 0,
        "fh-names": stats["definition_lines"] + stats["added_or_renamed"] > 0,
        "fh-declarations": True,
        "fh-tests": stats["test_files"] + stats["doc_files"] + stats["docstring_lines"] > 0,
        "fh-todos": stats["todo_lines"] > 0,
        "fh-docs": stats["doc_files"] + stats["skill_files"] > 0,
    }
    changed = stats["added_lines"] + stats["removed_lines"]
    size = "small" if changed < SMALL_LINES else "large" if stats["files"] > LARGE_FILES else "normal"
    agents = [n for n in DIFF_LENSES if lenses[n]]
    if size == "small" and agents:
        agents = ["diff-all"]
    agents += ["fh-claims", "fh-procedures", "fh-sweep-prose", "fh-sweep-declarations"]
    if stats["python_files"]:
        agents.insert(0, "fh-sweep-code")

    body = f"# {pr['title']}\n\n{pr['body'] or ''}\n" if pr else f"# {branch}\n\n(no PR yet)\n"
    (run_dir / "pr-body.md").write_text(body)

    write_json(run_dir / "scope.json", {
        "repo": name,
        "repo_path": repo,
        "pr": a.pr,
        "url": pr["url"] if pr else None,
        "title": pr["title"] if pr else branch,
        "base": base,
        "branch": branch,
        "head_sha": head_sha,
        "merge_base": merge_base,
        "mode": a.mode,
        "session_id": os.environ.get("CLAUDE_CODE_SESSION_ID"),
        "orchestrator_effort": os.environ.get("CLAUDE_EFFORT"),
        "started_at": datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z"),
        "size": size,
        "stats": stats,
        "files": [{"status": s, "path": p} for s, p in files],
        "lenses_skipped": [n for n in DIFF_LENSES if not lenses[n]],
        "agents": agents,
        "subject_area": None,
        "workflows": [],
    })

    print(f"run folder: {run_dir}")
    print(f"mode {a.mode}, size {size}: {stats['files']} files, +{stats['added_lines']} -{stats['removed_lines']}")
    print(f"agents: {', '.join(agents)}")
    skipped = [n for n in DIFF_LENSES if not lenses[n]]
    if skipped:
        print(f"skipped, nothing to inspect: {', '.join(skipped)}")
    if not os.environ.get("CLAUDE_CODE_SESSION_ID"):
        print("warning: CLAUDE_CODE_SESSION_ID unset, collect.py and usage.py will not find the transcripts")


if __name__ == "__main__":
    main()
