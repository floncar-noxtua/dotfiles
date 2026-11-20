#!/usr/bin/env bash
# Create branch <branch> and the worktree <main checkout>/.claude/worktrees/<branch>, then copy in the
# gitignored files listed in the repo's .worktreeinclude (one literal path per line, # comments).
# Usage: new-worktree.sh <branch> [base-ref, default origin/<default branch>]
set -euo pipefail

branch=${1:?usage: new-worktree.sh <branch> [base-ref]}
main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
default=$(git -C "$main" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
base=${2:-$default}
wt="$main/.claude/worktrees/$branch"

[ -e "$wt" ] && { echo "already exists: $wt" >&2; exit 1; }

if git -C "$main" show-ref --verify --quiet "refs/heads/$branch"; then
  git -C "$main" worktree add "$wt" "$branch"
else
  git -C "$main" fetch --quiet origin
  # --no-track: otherwise the new branch tracks the base and a bare `git push` targets it.
  git -C "$main" worktree add --no-track -b "$branch" "$wt" "$base"
fi

if [ -f "$main/.worktreeinclude" ]; then
  grep -v -e '^#' -e '^[[:space:]]*$' "$main/.worktreeinclude" | while IFS= read -r path; do
    if [ -f "$main/$path" ]; then
      mkdir -p "$(dirname "$wt/$path")"
      cp -p "$main/$path" "$wt/$path"
      echo "copied $path"
    else
      echo "skipped $path (not in main checkout)" >&2
    fi
  done
else
  echo "no .worktreeinclude in $main: nothing copied" >&2
fi

echo "worktree: $wt"
