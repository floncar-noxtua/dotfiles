#!/usr/bin/env python3
"""Write each diff-side agent only the changed lines its question needs, with HEAD line numbers.

usage: slice.py <run-dir>

Each lens keeps the changed lines its predicate matches, plus two lines of context. A slice
over MAX_BYTES is split by file into parts, one agent per part. Blind sweeps and cluster
judges get no slice: blindness is their point, and a cluster is its own input.
"""

import ast
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fh_lib import (  # noqa: E402
    CI_RE, CONFIG_RE, SKILL_RE, TEST_RE, TODO_RE, diff_range, git, parse_diff, scope, write_json,
)

MAX_BYTES = 30_000
CONTEXT = 2
STEP_RE = re.compile(r"(^\s*(\d+\.|[-*])\s)|\b(first|then|also update|remember|make sure|don't forget|"
                     r"step \d|after this|before you|run `)", re.I)
DECL_RE = re.compile(r"--[a-z][\w-]+|\buv run\b|\bjust \w|\b\d+\.\d+(\.\d+)?\b|:\d{2,5}\b|[=<>~]=|`[^`]+`")
BEHAVIOUR_RE = re.compile(r"\b(must|always|never|returns?|raises?|only|cannot|guarantees?|ensures?|should|"
                          r"defaults? to|is (not )?allowed)\b", re.I)
TEST_LINE_RE = re.compile(r"\bdef test_|\bassert\b|pytest\.(raises|mark)|\bxfail\b|parametrize")
PY_DECL_RE = re.compile(r"^\s*[A-Z_][A-Z0-9_]*\s*[:=]|default=|add_argument\(|environ|getenv\(")
DEF_RE = re.compile(r"\s*(class |def |async def |[A-Z_][A-Z0-9_]*\s*[:=])")


def docstring_lines(repo, path):
    try:
        tree = ast.parse((Path(repo) / path).read_text())
    except (SyntaxError, UnicodeDecodeError, OSError, ValueError):
        return set()
    out = set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            body = getattr(node, "body", [])
            if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant) \
                    and isinstance(body[0].value.value, str):
                out.update(range(body[0].lineno, body[0].end_lineno + 1))
    return out


def main():
    run_dir = Path(sys.argv[1]).expanduser()
    s = scope(run_dir)
    repo, rng = s["repo_path"], diff_range(s)
    parsed = parse_diff(git(repo, "diff", "-U3", rng))
    body = (run_dir / "pr-body.md").read_text()
    commits = git(repo, "log", "--format=commit %h%n%B", f"{s['merge_base']}..HEAD")
    status = "\n".join(f"{f['status']}\t{f['path']}" for f in s["files"])
    docs = {p: docstring_lines(repo, p) for p in parsed if p.endswith(".py")}

    def is_prose(path, sign, new, text):
        if not path.endswith(".py"):
            return False
        return (text.lstrip().startswith("#") or '"""' in text or "'''" in text
                or (sign == "+" and new in docs.get(path, set())))

    def is_md(path):
        return path.endswith(".md") or bool(SKILL_RE.search(path))

    predicates = {
        "fh-prose-at-site": is_prose,
        "fh-declarations": lambda p, s_, n, t: (
            bool(CONFIG_RE.search(p) or CI_RE.search(p))
            or (is_md(p) and bool(DECL_RE.search(t)))
            or (p.endswith(".py") and bool(PY_DECL_RE.search(t)))),
        "fh-tests": lambda p, s_, n, t: (
            (bool(TEST_RE.search(p)) and bool(TEST_LINE_RE.search(t)))
            or ((is_md(p) or is_prose(p, s_, n, t)) and bool(BEHAVIOUR_RE.search(t)))),
        "fh-todos": lambda p, s_, n, t: bool(TODO_RE.search(t)),
        "fh-docs": lambda p, s_, n, t: is_md(p),
        "diff-all": lambda p, s_, n, t: True,
    }
    proc = lambda p, s_, n, t: ((is_md(p) or CI_RE.search(p) or is_prose(p, s_, n, t))  # noqa: E731
                                and bool(STEP_RE.search(t)))

    def select(path, pred):
        """Changed lines matching pred, with CONTEXT lines either side, per hunk."""
        out = []
        for h in parsed.get(path, []):
            hits = [i for i, (sg, _, n, t) in enumerate(h) if sg != " " and pred(path, sg, n, t)]
            keep = sorted({j for i in hits for j in range(i - CONTEXT, i + CONTEXT + 1) if 0 <= j < len(h)})
            prev = None
            for j in keep:
                if prev is not None and j != prev + 1:
                    out.append("   ...")
                sg, old, new, t = h[j]
                out.append(f"+{new:>6}: {t}" if sg == "+" else f"-{'':>6}  {t}" if sg == "-" else f" {new:>6}: {t}")
                prev = j
            if keep:
                out.append("")
        return f"== {path}\n" + "\n".join(out) if out else ""

    def names(path, _pred=None):
        rows = [f"{path}:{n}: {t.strip()}" for h in parsed.get(path, []) for sg, _, n, t in h
                if sg == "+" and DEF_RE.match(t)]
        return "\n".join(rows)

    def pack(parts, header=""):
        """Group per-file texts into slices of at most MAX_BYTES."""
        slices, cur = [], header
        for text in parts:
            if not text:
                continue
            if len(cur) + len(text) > MAX_BYTES and cur.strip() != header.strip():
                slices.append(cur)
                cur = header
            cur += text + "\n"
        if cur.strip() and cur.strip() != header.strip():
            slices.append(cur)
        return slices

    paths = sorted(parsed)
    built = {}
    for agent in s["agents"]:
        if agent in predicates:
            built[agent] = pack([select(p, predicates[agent]) for p in paths])
        elif agent == "fh-names":
            built[agent] = pack([names(p) for p in paths], header=f"{status}\n\nAdded definitions:\n")
        elif agent == "fh-claims":
            built[agent] = [f"{body}\n\n## Commits\n\n{commits}\n## Files\n\n{status}\n"]
        elif agent == "fh-procedures":
            built[agent] = pack([select(p, proc) for p in paths],
                                header=f"{body}\n\n## Commits\n\n{commits}\n## Step-shaped prose in the diff\n\n")

    slices_dir = run_dir / "slices"
    slices_dir.mkdir(exist_ok=True)
    for old in slices_dir.glob("*.txt"):
        old.unlink()
    manifest = {}
    for agent, texts in built.items():
        files = []
        for i, text in enumerate(texts, 1):
            name = f"{agent}.{i}.txt" if len(texts) > 1 else f"{agent}.txt"
            (slices_dir / name).write_text(text)
            files.append(f"slices/{name}")
        manifest[agent] = files
    s["slices"] = manifest
    write_json(run_dir / "scope.json", s)
    empty = [a for a, f in manifest.items() if not f]
    print(f"slices: {sum(len(f) for f in manifest.values())} files for {len(manifest)} agents "
          f"(largest {max((len(t) for ts in built.values() for t in ts), default=0) // 1000} KB)")
    if empty:
        print(f"nothing to inspect after slicing, will not launch: {', '.join(empty)}")


if __name__ == "__main__":
    main()
