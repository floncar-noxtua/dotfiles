#!/usr/bin/env python3
"""PreToolUse hook for Bash: force a permission prompt for OBS writes.

Asks whenever a command runs raw `obsutil` with anything other
than a read: `ls`/`stat`, or `cp`/`sync` whose only obs:// URL is the source.
That covers rm, uploads (cp/sync to obs://), mv, mkdir, and so on.
If the command cannot be parsed and mentions obs, it asks (fail closed).
"""

import json
import os
import shlex
import sys

READ_ONLY = {"ls", "stat"}
COPY = {"cp", "sync"}
SEPARATORS = {";", "&&", "||", "|", "&", "(", ")", "\n"}
TOOLS = {"obsutil"}


def ask(reason: str) -> None:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": reason,
    }}))
    sys.exit(0)


def is_tool(token: str) -> bool:
    name = os.path.basename(token)
    return name in TOOLS or name.startswith("obsutil_")


def check(args: list[str]) -> str | None:
    """Return a reason to ask, or None if the call only reads."""
    if not args:
        return None
    sub, rest = args[0], args[1:]
    positional = [a for a in rest if not a.startswith("-")]
    if sub in READ_ONLY:
        return None
    if sub in COPY:
        if positional and positional[0].startswith("obs://") and not any(
            p.startswith("obs://") for p in positional[1:]
        ):
            return None
        return f"OBS upload ({sub} to obs://) - needs your approval"
    return f"OBS write/delete ({sub}) - needs your approval"


def main() -> None:
    try:
        cmd = json.load(sys.stdin).get("tool_input", {}).get("command") or ""
    except Exception:
        return
    if "obs" not in cmd:
        return
    try:
        lexer = shlex.shlex(cmd, posix=True, punctuation_chars=";&|()")
        lexer.whitespace_split = True
        tokens = list(lexer)
    except ValueError:
        ask("Unparseable command that mentions obs - needs your approval")

    i = 0
    while i < len(tokens):
        if is_tool(tokens[i]):
            j = i + 1
            while j < len(tokens) and tokens[j] not in SEPARATORS:
                j += 1
            reason = check(tokens[i + 1 : j])
            if reason:
                ask(reason)
            i = j
        else:
            i += 1


if __name__ == "__main__":
    main()
