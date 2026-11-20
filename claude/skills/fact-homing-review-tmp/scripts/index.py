#!/usr/bin/env python3
"""Phase 1: find every other site of each fact the diff defines, and write clusters.json.

usage: index.py <run-dir>

Python only. `ast` reads the definitions exactly; `rg` finds literals in every tracked text file.
A cluster is one fact key with at least one site that restates it outside its definition.
"""

import ast
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fh_lib import (  # noqa: E402
    added_lines, changed_files, diff_range, git, iter_repo_files, parse_diff, scope, sh, write_json,
)

MAX_LITERAL_HITS = 40
MAX_CONSUMERS = 15
STOP_STRINGS = {
    "utf-8", "utf8", "name", "type", "value", "data", "text", "true", "false", "none", "null", "self",
    "default", "error", "info", "debug", "warning", "json", "html", "http", "https", "index", "items",
    "keys", "path", "file", "list", "dict", "content", "title", "description", "status", "result",
    "results", "query", "source", "target", "label", "message", "string", "number", "object", "array",
    "strict", "ignore", "replace", "append", "update", "create", "delete", "date", "time", "count",
    "total", "size", "test", "tests", "main", "url", "uri", "user", "role", "mode", "kind", "code",
}
STOP_NUMBERS = {0, 1, 2, 3, -1, 10, 100, 1000, 0.0, 0.5, 1.0}
COMMON_FUNCS = {
    "main", "run", "setup", "teardown", "get", "set", "process", "handle", "execute", "validate",
    "to_dict", "from_dict", "dict", "apply", "transform", "load", "save", "close", "open", "build",
    "parse", "create", "update", "delete", "fetch", "call", "invoke", "model_post_init", "setUp", "tearDown",
}
LITERAL_RE = re.compile(r"^[A-Za-z0-9_.:/@{}\-]{4,120}$")
ENUM_BASES = {"Enum", "IntEnum", "StrEnum", "Flag", "IntFlag"}


def const_value(node):
    if isinstance(node, ast.Constant) and not isinstance(node.value, bool) and isinstance(node.value, (str, int, float)):
        return node.value
    return None


def base_names(cls):
    out = set()
    for b in cls.bases:
        if isinstance(b, ast.Name):
            out.add(b.id)
        elif isinstance(b, ast.Attribute):
            out.add(b.attr)
    return out


def index_module(rel, tree):
    """Module-level constants and collections, enums, field classes and functions."""
    idx = {"constants": [], "collections": [], "enums": [], "classes": [], "functions": []}
    for node in tree.body:
        targets, value = [], None
        if isinstance(node, ast.Assign):
            targets, value = [t for t in node.targets if isinstance(t, ast.Name)], node.value
        elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name) and node.value is not None:
            targets, value = [node.target], node.value
        for t in targets:
            v = const_value(value)
            if v is not None:
                idx["constants"].append({"name": t.id, "value": v, "line": node.lineno, "end": node.end_lineno})
            elif isinstance(value, (ast.List, ast.Tuple, ast.Set, ast.Dict)):
                elts = value.keys if isinstance(value, ast.Dict) else value.elts
                vals = {const_value(e) for e in elts if e is not None} - {None}
                vals = {v for v in vals if isinstance(v, str)}
                if len(vals) >= 2:
                    idx["collections"].append({"name": t.id, "values": sorted(vals), "line": node.lineno, "end": node.end_lineno})
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            if base_names(node) & ENUM_BASES:
                members = []
                for b in node.body:
                    if isinstance(b, ast.Assign) and len(b.targets) == 1 and isinstance(b.targets[0], ast.Name):
                        v = const_value(b.value)
                        if v is not None:
                            members.append({"name": b.targets[0].id, "value": v, "line": b.lineno})
                idx["enums"].append({"name": node.name, "members": members, "line": node.lineno, "end": node.end_lineno})
            else:
                fields = [b.target.id for b in node.body if isinstance(b, ast.AnnAssign) and isinstance(b.target, ast.Name)]
                if len(fields) >= 3:
                    idx["classes"].append({"name": node.name, "fields": fields, "line": node.lineno, "end": node.end_lineno})
    methods = {id(f) for c in ast.walk(tree) if isinstance(c, ast.ClassDef) for f in c.body}
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            args = [a.arg for a in node.args.posonlyargs + node.args.args + node.args.kwonlyargs if a.arg not in ("self", "cls")]
            idx["functions"].append({"name": node.name, "args": args, "line": node.lineno, "end": node.end_lineno,
                                     "method": id(node) in methods})
    return idx


def docstring_nodes(tree):
    out = set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            body = getattr(node, "body", [])
            if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant):
                out.add(id(body[0].value))
    return out


def literals_on_lines(tree, lines):
    skip = docstring_nodes(tree)
    for node in ast.walk(tree):
        if isinstance(node, ast.JoinedStr):
            skip.update(id(v) for v in node.values)
    for node in ast.walk(tree):
        if (isinstance(node, ast.Constant) and isinstance(node.value, str) and id(node) not in skip
                and node.lineno in lines and LITERAL_RE.match(node.value)
                and node.value.lower() not in STOP_STRINGS):
            yield node.value, node.lineno


def touches(item, lines):
    return any(item["line"] <= n <= (item.get("end") or item["line"]) for n in lines)


def main():
    run_dir = Path(sys.argv[1]).expanduser()
    s = scope(run_dir)
    repo = s["repo_path"]
    rng = diff_range(s)
    added = added_lines(parse_diff(git(repo, "diff", "-U0", rng)))
    changed_py = [p for st, p in changed_files(repo, rng) if st != "D" and p.endswith(".py")]

    sources, trees, index = {}, {}, {}
    for rel in iter_repo_files(repo, [".py"]):
        try:
            text = (Path(repo) / rel).read_text()
            tree = ast.parse(text)
        except (SyntaxError, UnicodeDecodeError, ValueError, OSError):
            continue
        sources[rel] = text.splitlines()
        trees[rel] = tree
        index[rel] = index_module(rel, tree)

    def quote(rel, line):
        lines = sources.get(rel)
        if lines is None:
            try:
                lines = (Path(repo) / rel).read_text().splitlines()
            except (OSError, UnicodeDecodeError):
                return ""
            sources[rel] = lines
        return lines[line - 1].strip()[:160] if 0 < line <= len(lines) else ""

    def site(rel, line, kind):
        return {"file": rel, "line": line, "kind": kind, "quote": quote(rel, line)}

    def is_diff_site(rel, line):
        return line in added.get(rel, set())

    rg_cache, too_common = {}, set()

    def literal_hits(lit):
        if lit in rg_cache:
            return rg_cache[lit]
        out = sh(["rg", "-n", "--no-heading", "--hidden", "-g", "!.git", "-F", "--", lit, "."], cwd=repo, check=False)
        bound = re.compile(r"(?<![A-Za-z0-9_])" + re.escape(lit) + r"(?![A-Za-z0-9_])")
        hits = []
        for row in out.splitlines():
            parts = row.split(":", 2)
            if len(parts) == 3 and parts[1].isdigit() and bound.search(parts[2]):
                hits.append((parts[0].removeprefix("./"), int(parts[1])))
        if len(hits) > MAX_LITERAL_HITS:
            too_common.add(lit)
            hits = []
        rg_cache[lit] = hits
        return hits

    def consumers(name, exclude):
        out = sh(["rg", "-n", "--no-heading", "-w", "-t", "py", "--", name, "."], cwd=repo, check=False)
        rows = []
        for row in out.splitlines():
            parts = row.split(":", 2)
            path = parts[0].removeprefix("./")
            if len(parts) == 3 and parts[1].isdigit() and (path, int(parts[1])) not in exclude:
                kind = "import" if re.search(r"\bimport\b", parts[2]) else "consumer"
                rows.append(site(path, int(parts[1]), kind))
        return rows[:MAX_CONSUMERS]

    clusters, covered = [], set()

    def add(key, key_kind, origin, defs, copies, name=None):
        copies = [c for c in copies if (c["file"], c["line"]) not in {(d["file"], d["line"]) for d in defs}]
        if not copies:
            return
        seen, sites = set(), []
        for x in defs + copies:
            k = (x["file"], x["line"])
            if k not in seen:
                seen.add(k)
                sites.append(x)
        used = {(x["file"], x["line"]) for x in sites}
        cons = consumers(name, used) if name else []
        clusters.append({
            "fact_key": key, "key_kind": key_kind, "origin": origin,
            "sites": sites + cons, "copies": len(copies), "consumers": len(cons),
        })

    all_items = [(rel, kind, item) for rel, idx in index.items() for kind, items in idx.items() for item in items]

    for rel in changed_py:
        if rel not in index:
            continue
        lines = added.get(rel, set())
        idx = index[rel]

        for e in (e for e in idx["enums"] if touches(e, lines)):
            values = {m["value"] for m in e["members"] if isinstance(m["value"], str)}
            covered.update(values)
            defs = [site(rel, e["line"], "definition")]
            copies = []
            for v in values:
                for f, n in literal_hits(v):
                    if not (f == rel and e["line"] <= n <= e["end"]):
                        copies.append(site(f, n, "copy"))
            for f2, k2, o in all_items:
                if (f2, o["line"]) == (rel, e["line"]):
                    continue
                other = ({m["value"] for m in o["members"]} if k2 == "enums"
                         else set(o["values"]) if k2 == "collections" else set())
                shared = values & other
                if len(shared) >= 2 and len(shared) >= 0.5 * min(len(values), len(other)):
                    copies.append(site(f2, o["line"], "copy"))
            add(f"{rel}::{e['name']}", "enum", {"file": rel, "line": e["line"], "name": e["name"]}, defs, copies, e["name"])

        for c in (c for c in idx["collections"] if touches(c, lines)):
            values = set(c["values"])
            covered.update(values)
            copies = []
            for f2, k2, o in all_items:
                if (f2, o["line"]) == (rel, c["line"]):
                    continue
                other = ({m["value"] for m in o["members"]} if k2 == "enums"
                         else set(o["values"]) if k2 == "collections" else set())
                shared = values & other
                if len(shared) >= 2 and len(shared) >= 0.6 * min(len(values), len(other)):
                    copies.append(site(f2, o["line"], "copy"))
            add(f"{rel}::{c['name']}", "collection", {"file": rel, "line": c["line"], "name": c["name"]},
                [site(rel, c["line"], "definition")], copies, c["name"])

        for k in (k for k in idx["constants"] if touches(k, lines)):
            v = k["value"]
            copies = []
            for f2, k2, o in all_items:
                if k2 != "constants" or (f2, o["line"]) == (rel, k["line"]):
                    continue
                if o["name"] == k["name"] or (o["value"] == v and v not in STOP_NUMBERS and not isinstance(v, str)):
                    copies.append(site(f2, o["line"], "copy"))
            if isinstance(v, str) and LITERAL_RE.match(v) and v.lower() not in STOP_STRINGS:
                covered.add(v)
                copies += [site(f, n, "copy") for f, n in literal_hits(v) if (f, n) != (rel, k["line"])]
            add(f"{rel}::{k['name']}", "constant", {"file": rel, "line": k["line"], "name": k["name"]},
                [site(rel, k["line"], "definition")], copies, k["name"])

        for c in (c for c in idx["classes"] if touches(c, lines)):
            fields = set(c["fields"])
            copies = []
            for f2, k2, o in all_items:
                if k2 != "classes" or (f2, o["line"]) == (rel, c["line"]):
                    continue
                other = set(o["fields"])
                if len(fields & other) / len(fields | other) >= 0.75:
                    copies.append(site(f2, o["line"], "copy"))
            add(f"{rel}::{c['name']}", "class", {"file": rel, "line": c["line"], "name": c["name"]},
                [site(rel, c["line"], "definition")], copies, c["name"])

        for fn in (fn for fn in idx["functions"] if fn["line"] in lines):
            # A public method sharing a name and signature is usually an implementation of one interface.
            if (fn["name"] in COMMON_FUNCS or fn["name"].startswith(("test_", "__"))
                    or (fn["method"] and not fn["name"].startswith("_"))):
                continue
            copies = [site(f2, o["line"], "copy") for f2, k2, o in all_items
                      if k2 == "functions" and o["name"] == fn["name"] and o["args"] == fn["args"]
                      and (f2, o["line"]) != (rel, fn["line"])]
            add(f"{rel}::{fn['name']}", "function", {"file": rel, "line": fn["line"], "name": fn["name"]},
                [site(rel, fn["line"], "definition")], copies, None)

    for rel in changed_py:
        if rel not in trees:
            continue
        for lit, line in literals_on_lines(trees[rel], added.get(rel, set())):
            if lit in covered:
                continue
            covered.add(lit)
            hits = literal_hits(lit)
            defs = [site(f, n, "definition") for f, n in hits if is_diff_site(f, n)]
            copies = [site(f, n, "copy") for f, n in hits if not is_diff_site(f, n)]
            add(f'"{lit}"', "literal", {"file": rel, "line": line, "name": lit},
                defs or [site(rel, line, "definition")], copies)

    seen_sets, unique = set(), []
    for c in clusters:
        sig = frozenset((x["file"], x["line"]) for x in c["sites"] if x["kind"] != "consumer")
        if sig not in seen_sets:
            seen_sets.add(sig)
            unique.append(c)
    order = {"enum": 0, "collection": 1, "constant": 2, "class": 3, "function": 4, "literal": 5}
    # Named definitions first: a loose literal shared across modules is more often a coincidence.
    unique.sort(key=lambda c: (order[c["key_kind"]] == order["literal"], -c["copies"], order[c["key_kind"]]))
    for i, c in enumerate(unique, 1):
        c["id"] = f"c{i:02d}"

    write_json(run_dir / "clusters.json", {
        "clusters": unique,
        "skipped_too_common": sorted(too_common),
        "files_indexed": len(index),
    })
    kinds = defaultdict(int)
    for c in unique:
        kinds[c["key_kind"]] += 1
    print(f"{len(unique)} clusters ({', '.join(f'{v} {k}' for k, v in kinds.items()) or 'none'}); "
          f"{len(too_common)} literals skipped as too common; {len(index)} Python files indexed")
    for c in unique[:10]:
        print(f"  {c['id']} {c['key_kind']:<10} {c['fact_key']}  copies={c['copies']}")


if __name__ == "__main__":
    main()
