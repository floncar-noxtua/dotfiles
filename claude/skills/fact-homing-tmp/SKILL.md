---
name: fact-homing-tmp
description: Load the fact-homing standard (`references/fact-homing.md` in this skill) as the reference for this conversation and judge questions, code or prose against it fact by fact, quoting the exact passage behind every remark or saying the document does not state it. Use when the user invokes /fact-homing-tmp or /fact-homing, asks what the standard says, asks where a fact, comment, doc, TODO or procedure should live, or asks whether code, a doc, a skill or a PR is in line with the standard, even when the answer seems obvious from the repo docs.
---

# One fact, one home

Judges whatever it is pointed at - a question, code, prose - through `references/fact-homing.md`, one fact at a time, every remark quoted from the document.

**The repo's own rules win.** When the skill loads, read the `AGENTS.md` and `README.md` at the root of the repo in hand. Where either disagrees with this skill, the standard or the repo profile - a test layout, a recipe, a writing style, where a fact belongs - follow the repo, quote the repo file as you would the standard and say it overrides.

**This skill holds nothing about any one repo.** Where the repo in hand departs from the standard lives in its **repo profile**, a file git never tracks, which step 2 checks on every run and [Creating the profile](#creating-the-profile) builds. `S=~/.claude/skills/fact-homing-tmp/scripts` below.

## When to use
- A question on what the standard says or where something belongs.
- A check of code, a doc, a skill, agent instructions, a PR or a commit message against the standard.
- Not for a whole PR or branch: use `fact-homing-review-tmp`, which runs these judgments with a team of agents.
- Not for correctness bugs: use `/code-review`.

## Read first
- [`references/fact-homing.md`](references/fact-homing.md) - the standard, a copy of data-pipeline's `docs/fact-homing.md`
- The repo's `docs/skills.md`, where it has one - "Pointer rules": how a scope is declared there

## Process

### 1. Load
Read `references/fact-homing.md` in full every time this skill runs, even if an earlier copy is in context - it may have changed. Say in one line that it is loaded; do not summarise it. For the rest of the conversation it is the reference for every remark on where facts, prose, comments, docs or procedures belong.

### 2. Repo profile - gate
Run `python3 $S/repo_profile.py status` from inside the repo, once per conversation.
- **It exists:** show when and at which commit it was built and how many commits have landed since, then ask with `AskUserQuestion`: **Use as is** or **Recreate**. Recreate runs [Creating the profile](#creating-the-profile).
- **It does not (exit 3):** ask **Create** or **Go without**. Without one, judge by the standard and the repo's `AGENTS.md` and `README.md` only, and say once that rulings may miss where the repo departs from the standard.

Then read it with `python3 $S/repo_profile.py sections` before the first ruling. Never cite an exception in it as precedent, and never report one as a new finding unless asked - name it where a ruling rests on it.

### 3. Cite - every remark, no exceptions
- A remark the document supports carries the **exact passage**, verbatim, as a Markdown blockquote, followed by its section in brackets, e.g. `- (The ladder)`. Quote the shortest span that carries the point. Do not paraphrase inside the quote, do not stitch separate sentences into one quote and keep the original emphasis.
- A remark the document does not support is marked **Not stated in the document.** - then give the view as your own judgement, labelled as such, or drop it.
- An inference that combines passages quotes each passage, then states the inference separately as yours.
- A remark that rests on a repo exception names it, e.g. "(exception: CI blocks no merge)".
- When unsure, re-read the file rather than quote from memory.

### 4. List the facts
Split what you were pointed at into facts before judging anything. A file, paragraph or answer is never the unit.
- **Code or prose under review:** one fact per claim - a value, a rule, a step, a why, a pointer. A sentence that mixes a standing claim with an event is two facts. Find every other site that states the same fact (`grep` for its names and values) and list them with it.
- **A question:** the fact the user holds or asks about. A question about the standard itself ("what is a freezing home?") has no facts to list: answer it with quotes and stop.
- **Text being written:** check each fact before it goes in, the same way.

### 5. Judge each fact
Answer these for each fact, each with its quote.
1. **Kind** - state, rule or action; about the code, the world or a convention; standing or an event; does it carry a why. (Facts)
2. **Home now** - which row of the homes table it sits in, how that home ends and what ties it: fails, displays or nothing. Apply the repo profile here. (Homes)
3. **Where it belongs** - record or ticket for events and open work, else the first ladder rung that works, and why each earlier rung does not. Check for an existing declaration first. (The ladder, The cheapest home is the code)
4. **Placing** - for prose that stays: the reader, the moment and the pointer from where that reader starts. (Placing)
5. **Verdict** - **in line** when the fact already sits where steps 3 and 4 put it, otherwise **not in line**, with the concrete change.

### 6. Report
One block per fact, findings first, ordered by how much tie the change gains (nothing to fails first), then facts in line in one line each with their quote:

```markdown
#### <n>. <the fact in one sentence> - not in line
- **Sites:** `path:line` (or the quoted text), every copy
- **Kind:** <kind>
  > <quote> - (Facts)
- **Home now:** <home, tie>
  > <quote> - (Homes)
- **Belongs:** <rung or record>
  > <quote> - (The ladder)
- **Change:** <the exact edit, or the ticket to file>
```

End with the facts you could not rule on and why. Nothing is edited unless the user asks.

## Creating the profile

The profile lists where the repo in hand departs from the standard, with the evidence for each line, so a ruling applies the standard as this repo can carry it. It is derived from the repo and its settings, never written from memory.

1. **Survey**, citing the command or `file:line` behind each observation:
   - `AGENTS.md`, `README.md` and `CLAUDE.md`: each rule that disagrees with the standard, and each line the standard's own test for that home rules out ("Agent instructions", "README.md").
   - The project and lint config: what the linter and type checker skip, whether the test runner collects doctests, whether `xfail` is strict.
   - CI: which checks run, on which events, and whether any runs on a schedule. With `gh api repos/{owner}/{repo}` and its branch protection and rulesets: whether a check blocks a merge, and which text a squash merge keeps as the commit body.
   - Where scoped docs are declared and what loads them (the referee), whether ADRs or a dated log exist, and whether the repo has a generator.
   - `TODO`s: whether they name tickets or people.
2. **Write each entry** as one bullet: what departs, the evidence with the date it was observed, and the ticket that fixes it. Take the ticket only from the repo - a `TODO(<ticket>)`, a test that states the exception, a committed list - or ask the human; never guess one. No ticket: write "no ticket".
3. **Sort the entries** into three sections, under exactly these headings:
   - `## Where the repo's rules override the standard` - an `AGENTS.md` or `README.md` rule that disagrees with the standard. The repo wins.
   - `## Repo exceptions` - where the repo does not follow the standard yet: pending decisions, homes that do not fail, prose that breaks it.
   - `## Repo facts the standard relies on` - settings outside the repo a ruling depends on, such as the merge setting.
4. **Gate.** Show the draft in full and wait for an explicit yes. Then write it to the path `python3 $S/repo_profile.py path` prints, starting with `# Fact-homing repo profile: <repo>` and the line `Built: <YYYY-MM-DD> at <short sha of HEAD>`, which `status` reads. A recreate replaces the file; say which entries it added and dropped.

## Red flags
- A quote not found verbatim in `references/fact-homing.md`.
- A remark with neither a quote nor "Not stated in the document."
- A ruling on a whole file or paragraph instead of on each fact in it.
- A repo exception reported as a finding, or cited as precedent.
