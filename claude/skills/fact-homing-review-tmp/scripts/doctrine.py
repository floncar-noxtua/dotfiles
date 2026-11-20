#!/usr/bin/env python3
"""Print named sections of the fact-homing standard, so an agent reads only what its question needs.

usage: doctrine.py summary | all | exceptions | "<heading>" ...
  summary     the lines above the first section
  all         the whole standard
  exceptions  the repo profile (where the repo under review departs from the standard), then that repo's
              AGENTS.md and README.md, which override both
  "<heading>" any heading, at any level: "The ladder", "World facts", "Skills"

The standard is the copy in `fact-homing-tmp/references/fact-homing.md`; the profile is read through
`fact-homing-tmp/scripts/repo_profile.py`, and the orchestrator decides in phase 0 whether one is used. An unknown
heading exits 1 and lists the headings. Run from inside the repo under review.
"""

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fh_lib import DOCTRINE, PROFILE_SCRIPT, REPO_RULE_FILES, headings, section, target_repo  # noqa: E402

NO_PROFILE = ("## Repo profile\n\nThis repo has no profile, so where it departs from the standard is not listed. "
              "Judge by the standard and the repo's own rules below, and say in `notes` where a ruling would turn on "
              "a repo setting you could not check.\n")
PRECEDENCE = ("## Rules of the repo under review\n\nThe files below are the repo's own rules. Where they disagree "
              "with the standard, the profile above, the finding contract or your brief, they win: judge by them "
              "and name the file in `exception`.")


def profile():
    out = subprocess.run([sys.executable, str(PROFILE_SCRIPT), "sections"], capture_output=True, text=True,
                         errors="replace")
    return out.stdout if out.returncode == 0 else NO_PROFILE


def repo_rules():
    repo = target_repo()
    parts = [PRECEDENCE]
    for name in REPO_RULE_FILES:
        path = repo / name
        if path.is_file():
            parts.append(f"### {repo.name}/{name}\n\n{path.read_text().strip()}")
    return "\n\n".join(parts) + "\n"


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    text = DOCTRINE.read_text()
    for want in sys.argv[1:]:
        if want == "all":
            print(text)
        elif want == "summary":
            print(text.split("\n## ", 1)[0])
        elif want == "exceptions":
            print(profile())
            print(repo_rules())
        else:
            body = section(text, want)
            if body is None:
                raise SystemExit(f"no section '{want}' in {DOCTRINE}; headings are:\n" + "\n".join(headings(text)))
            print(body)


if __name__ == "__main__":
    main()
