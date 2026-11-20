---
name: new-worktree
description: Create a git branch and a worktree of the same name under .claude/worktrees/, copy the repo's gitignored local files (listed in .worktreeinclude) into it, and switch the session there. Use in any repo when the user says "new worktree <branch>", "create a worktree", or "work on <branch> in a worktree".
---

Do not use the built-in `EnterWorktree name:` — it names the branch `worktree-<name>`, and here the
branch and the folder share one name.

1. Run `bash ~/.claude/skills/new-worktree/scripts/new-worktree.sh <branch>` from inside the repo.
   Add a second argument for a base other than `origin/<default branch>`. An existing local branch is
   checked out rather than created. The script copies every path in the repo's `.worktreeinclude`
   (in noxtua: `.env`, `ai-kitty/config/local.toml`); if the repo has none, say so and offer to add one.
   Copies, not symlinks: a mounted config folder would hold a symlink to a host path that dangles in a
   container, and a branch may need its own config.
2. Call `EnterWorktree` with `path: <main checkout>/.claude/worktrees/<branch>` (the script prints it).
