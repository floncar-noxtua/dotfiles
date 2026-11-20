#!/usr/bin/env python3
"""Find and date the repo profile: where the repo in hand departs from the fact-homing standard.

usage: repo_profile.py path | status | sections

  path      print where the profile lives: <git common dir>/fact-homing/profile.md. Git never tracks it, and
            every worktree of the repo shares it.
  status    print whether it exists and, if so, when and at which commit it was built and how many commits
            have landed since. Exit 0 when it exists, 3 when it does not.
  sections  print the profile's sections for an agent to read; exit 3 when there is none.

Run from inside the repo. The fact-homing-tmp skill writes the file; this script only reads it.
"""

import re
import subprocess
import sys
from pathlib import Path

SECTIONS = ("Where the repo's rules override the standard", "Repo exceptions", "Repo facts the standard relies on")
MISSING = 3


def git(*args):
    out = subprocess.run(["git", *args], capture_output=True, text=True, errors="replace")
    if out.returncode:
        raise SystemExit(f"git {' '.join(args)} failed: {out.stderr.strip()}")
    return out.stdout.strip()


def profile_path():
    return Path(git("rev-parse", "--path-format=absolute", "--git-common-dir")) / "fact-homing" / "profile.md"


def header(text):
    """The `Built:` line: `Built: <date> at <sha>`."""
    m = re.search(r"^Built: (\S+) at ([0-9a-f]{7,40})", text, flags=re.MULTILINE)
    return (m.group(1), m.group(2)) if m else (None, None)


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("path", "status", "sections"):
        raise SystemExit(__doc__)
    path = profile_path()
    if sys.argv[1] == "path":
        print(path)
        return
    if not path.is_file():
        print(f"no profile at {path}")
        sys.exit(MISSING)
    text = path.read_text()
    if sys.argv[1] == "sections":
        print(text)
        return
    date, sha = header(text)
    since = "unknown"
    if sha:
        out = subprocess.run(["git", "rev-list", "--count", f"{sha}..HEAD"], capture_output=True, text=True)
        since = out.stdout.strip() if out.returncode == 0 else "unknown (commit not in this clone)"
    print(f"profile: {path}\nbuilt: {date or 'unknown'} at {sha or 'unknown'}; commits since: {since}")


if __name__ == "__main__":
    main()
