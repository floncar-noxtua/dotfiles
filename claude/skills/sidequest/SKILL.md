---
name: sidequest
description: "Park a code finding that is worth doing but not on the current task's critical path - a bug, perf issue, missing test, refactor or security smell noticed while developing - with `sidequest add`, then return to the task. Also list, show, pick up, note or close parked sidequests. Use whenever you notice such a finding mid-task, or when the user says 'park this', 'sidequest', 'what sidequests are open', or 'pick up sidequest X'. Not for non-code TODOs (create-todo) or Jira (create-ticket)."
---

# Sidequest

`sidequest` (`~/.local/bin/sidequest`, source `~/dotfiles/bin/sidequest`) stores one markdown
file per finding in `~/.sidequests/<repo>/<id>.md`. It fills in repo, branch, commit, dirty
state, timestamps and a code excerpt itself. Run `sidequest <cmd> --help` for flags.

## When to park

Park when the finding is real, in code you have seen, and **not needed** to reach the current
goal. If it blocks the goal, it is not a sidequest - fix it or tell the user. Park in one
command and continue; do not investigate further, do not fix it, do not discuss it in the reply
beyond one line.

## What to write

You have context now that the next agent will not. Spend it on evidence, not on a plan:

```bash
sidequest add --name "<one-line claim>" --where <path:LINE | path:A-B | path::symbol> \
  --kind <bug|perf|refactor|test-gap|security|docs|cleanup> --sev <low|med|high> \
  --while "<the goal you are working on>" <<'EOF'
## Saw
<what is wrong, concretely: values, the call path, the log line or command that shows it>
## Why it matters
<the consequence, and when it bites>
## Idea (unverified)
<optional, one or two lines>
EOF
```

- `--name` states the problem as a claim ("Pool size hard-coded to 5"), not a task ("Look at pool").
- `--where` points at the line or symbol that shows it, so the excerpt is captured.
- If `add` prints a possible duplicate, check it with `sidequest show <id>`. If it is the same
  finding, move anything new into it with `sidequest note <id>` and close yours with
  `sidequest drop <new-id> --reason "dup of <id>"`.

## Working on a sidequest

Only when the user asks. `sidequest pick <id>` prints a starting prompt; confirm the problem
still exists, agree a done-check, then `sidequest done <id> --reason "..."` or
`sidequest drop <id> --reason "..."`. `sidequest check --mark` flags items whose excerpt no
longer matches the code.
