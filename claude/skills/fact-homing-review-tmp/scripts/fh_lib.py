"""Shared helpers for the fact-homing-review scripts: paths, git, diff parsing, the run folder and the
pure decisions the orchestrator would otherwise make by eye - collide, route and rank."""

import json
import os
import re
import subprocess
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
AGENTS_DIR = SKILL_DIR.parents[1] / "agents"
# The standard and the profile script live in the sibling fact-homing-tmp skill. The repo under review is wherever
# the orchestrator runs, so its profile, AGENTS.md and README.md are found from the working directory, not from here.
FACT_HOMING_SKILL = SKILL_DIR.parent / "fact-homing-tmp"
DOCTRINE = FACT_HOMING_SKILL / "references" / "fact-homing.md"
PROFILE_SCRIPT = FACT_HOMING_SKILL / "scripts" / "repo_profile.py"
REPO_RULE_FILES = ("AGENTS.md", "README.md")
RUNS_ROOT = Path(os.environ.get("FACT_HOMING_RUNS", Path.home() / ".local" / "state" / "fact-homing-review"))
PROJECTS = Path.home() / ".claude" / "projects"

SKIP_DIRS = {
    ".git", ".venv", "venv", "node_modules", "__pycache__", "dist", "build",
    ".mypy_cache", ".ruff_cache", ".pytest_cache", "site-packages", ".tox",
}
TEST_RE = re.compile(r"(^|/)(tests?/|test_[^/]*\.py$|[^/]*_test\.py$|conftest\.py$)")
CONFIG_RE = re.compile(r"\.(ya?ml|toml|json|ini|cfg|env)$|(^|/)(justfile|Makefile|Dockerfile)$")
CI_RE = re.compile(r"^\.github/workflows/")
SKILL_RE = re.compile(r"(^|/)\.claude/(skills|agents|rules)/")
DOC_RE = re.compile(r"\.md$")
TODO_RE = re.compile(r"\b(TODO|FIXME|XXX|HACK)\b")

# Lenses whose findings always claim something about sites they may not list: a copy elsewhere, every
# step of a procedure, what a commit says about the whole change. A light refuter cannot check those.
GLOBAL_LENSES = {"ssot", "procedure", "claim"}
SEVERITY = {"silent": 0, "loud": 1, "hygiene": 2}


def sh(args, cwd=None, check=True):
    # A repo can hold a file in another encoding; one undecodable byte in a search hit must not end the run.
    out = subprocess.run(args, cwd=cwd, capture_output=True, text=True, errors="replace", stdin=subprocess.DEVNULL)
    if check and out.returncode != 0:
        raise SystemExit(f"command failed: {' '.join(args)}\n{out.stderr.strip()}")
    return out.stdout


def git(repo, *args, check=True):
    return sh(["git", *args], cwd=repo, check=check)


def target_repo():
    """The repository under review: the git top level of the working directory."""
    return Path(git(".", "rev-parse", "--show-toplevel").strip())


def read_json(path, default=None):
    p = Path(path)
    if not p.exists():
        return default
    return json.loads(p.read_text())


def write_json(path, data):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def scope(run_dir):
    s = read_json(Path(run_dir) / "scope.json")
    if s is None:
        raise SystemExit(f"no scope.json in {run_dir}; run triage.py first")
    return s


def diff_range(s):
    return f"{s['merge_base']}...HEAD"


def changed_files(repo, rng):
    """[(status, path)] with renames reported under their new path."""
    rows = []
    for line in git(repo, "diff", "--name-status", "-M", rng).splitlines():
        parts = line.split("\t")
        rows.append((parts[0][0], parts[-1]))
    return rows


def parse_diff(text):
    """Unified diff -> {path: [hunk]}; a hunk is a list of (sign, old_no, new_no, text)."""
    files, path, hunk = {}, None, None
    old_no = new_no = 0
    for raw in text.splitlines():
        if raw.startswith("diff --git"):
            path, hunk = None, None
            continue
        if raw.startswith("+++ "):
            p = raw[4:]
            path = None if p == "/dev/null" else p[2:] if p.startswith("b/") else p
            if path:
                files.setdefault(path, [])
            continue
        if raw.startswith("--- "):
            continue
        m = re.match(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", raw)
        if m:
            old_no, new_no = int(m.group(1)), int(m.group(2))
            hunk = []
            if path:
                files[path].append(hunk)
            continue
        if hunk is None or path is None or raw.startswith("\\"):
            continue
        sign, body = raw[:1], raw[1:]
        if sign == "+":
            hunk.append(("+", None, new_no, body))
            new_no += 1
        elif sign == "-":
            hunk.append(("-", old_no, None, body))
            old_no += 1
        else:
            hunk.append((" ", old_no, new_no, body))
            old_no += 1
            new_no += 1
    return files


def added_lines(parsed):
    """{path: set(new line numbers added or changed)}."""
    return {p: {n for h in hunks for s, _, n, _ in h if s == "+"} for p, hunks in parsed.items()}


def iter_repo_files(repo, suffixes=None):
    """Tracked files only, so build output and vendored code stay out."""
    for rel in git(repo, "ls-files").splitlines():
        if any(part in SKIP_DIRS for part in Path(rel).parts):
            continue
        if suffixes and not rel.endswith(tuple(suffixes)):
            continue
        yield rel


def session_dir(session_id):
    hits = list(PROJECTS.glob(f"*/{session_id}"))
    return hits[0] if hits else None


def session_transcript(session_id):
    hits = list(PROJECTS.glob(f"*/{session_id}.jsonl"))
    return hits[0] if hits else None


def section(text, heading):
    """The body under a Markdown heading of any level, up to the next heading of the same or a higher level."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        m = re.match(r"^(#+) (.+?)\s*$", line)
        if m and m.group(2) == heading:
            level = len(m.group(1))
            out = [line]
            for nxt in lines[i + 1:]:
                n = re.match(r"^(#+) ", nxt)
                if n and len(n.group(1)) <= level:
                    break
                out.append(nxt)
            return "\n".join(out).rstrip() + "\n"
    return None


def headings(text):
    return [m.group(2) for m in re.finditer(r"^(#+) (.+?)\s*$", text, flags=re.MULTILINE)]


def norm_key(key):
    return re.sub(r"\s+", " ", key.strip()).lower()


def collide(raw):
    """One finding per fact key, every site attached once; the most severe statement leads.

    Findings two lenses phrase with different keys stay apart here; the merge judge rules on those
    after the refuters have completed their site lists.
    """
    groups = {}
    for f in raw:
        groups.setdefault(norm_key(f["fact_key"]), []).append(f)
    merged = []
    for fs in groups.values():
        fs = sorted(fs, key=lambda f: (f["lens"] != "ssot", SEVERITY[f["consequence"]]))
        lead = dict(fs[0])
        seen, sites = set(), []
        for f in fs:
            for s in f["sites"]:
                k = (s["file"], s["line"])
                if k not in seen:
                    seen.add(k)
                    sites.append(s)
        lead["sites"] = sites
        lead["consequence"] = min((f["consequence"] for f in fs), key=SEVERITY.get)
        lead["scope"] = "global" if any(f.get("scope") == "global" for f in fs) else "local"
        lead["ambiguous"] = any(f.get("ambiguous") for f in fs)
        lead["question"] = next((f["question"] for f in fs if f.get("question")), "")
        lead["rationale"] = " ".join(dict.fromkeys(f["rationale"] for f in fs))
        lead["agents"] = sorted({f["agent"] for f in fs})
        merged.append(lead)
    merged.sort(key=rank)
    for i, f in enumerate(merged, 1):
        f["id"] = f"F{i:02d}"
    return merged


def route(f, blind_agents=()):
    """`strong`: two sonnet refuters, one per angle. `light`: one haiku refuter that may escalate.

    A claim that looks local but rests on what the finding does not list - "only caller", "no other
    copy", "every step" - is where a cheap model confirms after a shallow search, so it goes strong.
    """
    if (f["lens"] in GLOBAL_LENSES or f.get("scope") == "global" or f["consequence"] == "silent"
            or any(a in blind_agents for a in f.get("agents", []))):
        return "strong"
    return "light"


def rank(f):
    """Silent single-source drift first, then by consequence; prose about the world after code."""
    sev = SEVERITY[f["consequence"]]
    return (0 if f["lens"] == "ssot" and f["consequence"] == "silent" else sev + 1,
            f["lens"] != "ssot", f.get("about") != "code", f.get("id", ""))


def overlap_components(findings):
    """Groups of finding ids that share a non-consumer site, transitively. Singletons are left out."""
    parent = {f["id"]: f["id"] for f in findings}

    def root(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    owner = {}
    for f in findings:
        for s in f["sites"]:
            if s.get("role") == "consumer":
                continue
            k = (s["file"], s["line"])
            if k in owner:
                parent[root(f["id"])] = root(owner[k])
            else:
                owner[k] = f["id"]
    comps = {}
    for f in findings:
        comps.setdefault(root(f["id"]), []).append(f["id"])
    return [sorted(c) for c in comps.values() if len(c) > 1]


def file_groups(findings):
    """Findings grouped so no two groups share a file, so no two proposers edit one file."""
    parent = {}

    def root(x):
        parent.setdefault(x, x)
        while parent[x] != x:
            x = parent[x]
        return x

    for f in findings:
        files = [s["file"] for s in f["sites"]]
        for other in files[1:]:
            parent[root(other)] = root(files[0])
    buckets = {}
    for f in findings:
        buckets.setdefault(root(f["sites"][0]["file"]), []).append(f)
    return [{"id": f"g{i}", "findings": [f["id"] for f in fs],
             "files": sorted({s["file"] for f in fs for s in f["sites"]})}
            for i, fs in enumerate(buckets.values(), 1)]
