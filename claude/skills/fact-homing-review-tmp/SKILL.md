---
name: fact-homing-review-tmp
description: Reviews a whole pull request or branch against the fact-homing standard with a team of read-only agents and ends in edits the human approved - applied to the branch in author mode, posted on the PR in reviewer mode - plus a commit body. Use when the user asks to run fact-homing-review, to review a PR or branch for fact homing, a single source of truth, duplicated constants, retyped config, stale docs or comments around a change, or to make a PR easier to review under the standard, even when the diff looks small. Not for one question or one file: use fact-homing-tmp.
---

# Fact-homing review

Turns a diff into a ranked, verified list of exact edits that give every fact one home, ruled on by the human. Scripts find what text can find, cheap agents check what is local, strong agents what is not, an arbiter settles disagreement and the human decides only intent.

**The repo's own rules win.** Before phase 0, read the `AGENTS.md` and `README.md` of the repo under review. Where either disagrees with this skill, the standard, the repo profile, the finding contract or a brief - a recipe, a test layout, a writing style, where a fact belongs - follow the repo and say which file decided. Agents get both files through `doctrine.py exceptions`.

**You are the orchestrator; your context is the scarcest thing in the run.** State lives in the run folder, agents return validated objects that scripts collect, and you read code only where the arbiter left a finding open. Never load a changed file before phase 4.

## When to use
- A PR or branch, in author mode (you own it) or reviewer mode (someone else's).
- Not for one question, file or paragraph: use `fact-homing-tmp`. Not for correctness: use `/code-review`.
- Needs a live user for phases 5, 7 and 10, and `gh` for a PR.

## Read first
- [`fact-homing.md`](../fact-homing-tmp/references/fact-homing.md) - the standard. Agents read it by section through `scripts/doctrine.py`; never paste it into a prompt.
- The repo profile - where the repo under review departs from the standard, in a file git never tracks. "Creating the profile" in the [`fact-homing-tmp` skill](../fact-homing-tmp/SKILL.md) builds it; `doctrine.py exceptions` prints it, then the repo's `AGENTS.md` and `README.md`.

Each agent's brief is `~/.claude/agents/fh-<name>.md`, the shared rules [`references/finding-contract.md`](references/finding-contract.md) and each agent's model and effort the `ROSTER` of the workflow script that starts it. Never retype any of them. Two principles decide every ruling:

- **The code is the truth** for a fact about the code. Where prose, a name, a test or a claim disagrees, the other thing is wrong.
- **Ambiguity goes to the human.** Whether two sites are one fact, and which is the source, is asked, never guessed.

`S=~/.claude/skills/fact-homing-review-tmp/scripts` below, run from the root of the repo under review. Every script takes the run folder `$R`.

## Process

### 0. Scope
If the user names a run folder, or `$FACT_HOMING_RUNS` (default `~/.local/state/fact-homing-review/`) holds one for this PR, run `python3 $S/state.py next $R` and resume at the phase it names.

1. **Repo profile - gate.** `python3 ~/.claude/skills/fact-homing-tmp/scripts/repo_profile.py status`. If it exists, show its build date, commit and the commits since, and ask **Use as is** or **Recreate**; if not (exit 3), ask **Create** or **Go without**. Ask it in the same `AskUserQuestion` call as the mode. Create and Recreate follow "Creating the profile" in `fact-homing-tmp`, including its gate, before triage. Agents read whatever the file holds when they start; without one they judge by the standard and the repo's own rules.
2. Ask the mode with `AskUserQuestion` unless the user said it.
3. Check out the PR head (`gh pr checkout <N>`, after a yes if the tree is dirty). For a branch with no PR, use `--base <branch>`.
4. `python3 $S/triage.py --pr <N> --mode <mode>`. Read nothing else.
5. Write the **subject area**: one or two sentences on what the change is about, with no file or symbol names. The blind sweeps get only this.

### 1. Index and slice
`python3 $S/index.py $R`, then `python3 $S/slice.py $R`. Report the cluster count in one line. Do not open `clusters.json` or the slices.

### 2. Detect
`python3 $S/state.py plan-detect $R --subject "<subject area>"` prints the args; over 30 clusters it judges the first 30 - say how many it left. Add `--override <agent>=<model>[/<effort>]` only to change one agent on purpose. Call `Workflow` with those args, verbatim, and `$S/detect.js` (see [Calling a workflow](#calling-a-workflow)); invoking this skill is the opt-in. Then `python3 $S/collect.py detect $R <runId>`: it collides findings by fact key and routes each - **strong** for global scope, single-source, procedures, claims, silent consequences and blind sweeps; **light** for the rest.

### 3. Verify
`python3 $S/state.py plan-verify $R`, `Workflow` with `$S/verify.js`, then `python3 $S/collect.py verify $R <runId>` and `python3 $S/state.py summary $R`. The workflow refutes by route - a light refuter escalates to two strong ones when the finding needs more than its sites - sends splits to the opus arbiter and lets a judge merge one fact found twice. Refuters never see the detector's rationale.

### 4. Settle what is left open
Only for findings still UNCERTAIN or SPLIT: `state.py show $R <id> --full`, then a targeted `rg -n` or `sed -n` of the sites, never whole files. `state.py set-verdict $R <id> CONFIRMED|REFUTED|AMBIGUOUS "<file:line and why>"`. Merge by hand only what the summary shows plainly as one fact: `state.py merge $R <keep> <other> ...`.

### 5. Clarify - gate
Every AMBIGUOUS finding goes to the human before anything is proposed, one per question, up to four per `AskUserQuestion` call. Lead with the fact, list each site as `file:line` with its quote, and offer "same fact, source is `<site>`", "different facts, leave both", "new shared home" (where, in Other) and "`<site>` holds the right value". Save each answer as it comes: `state.py clarify $R <id> "<answer>"`, with `--close` when it ends the finding and `--adds-site <file:line>` for every site the answer names that the finding did not list. Only those get rechecked; nothing re-judges a ruling.

### 6. Propose
`python3 $S/state.py plan-propose $R`, `Workflow` with `$S/propose.js`, then `python3 $S/collect.py propose $R <runId>`. It names any proposal still incomplete after one retry; settle those like phase 4 or rule them follow-ups.

### 7. Rule - gate
In `state.py summary` order, `state.py show $R <id>` and ask one question per finding, up to four per call: the claim, every site with role and `file:line`, then step, home and edits as the option `preview`. Options: **Approve**, **Drop**, **Follow-up**, **Explain**; amending is typed in Other. Batch findings of one mechanical shape into one question. Save each answer at once with `state.py rule $R <id> approve|drop|follow-up|amend`.
- **Amend**: their wording wins. Write their edits as JSON in the proposal's edit shape to `$R` and pass `--edits`, or `--note` alone when they changed the intent.
- **Follow-up**: `--ticket "<text>"`. Offer to file it in Jira; file nothing without a yes. Only a filed ticket earns a `TODO` pointer.
- **Explain**: answer from `state.py show $R <id> --full` and quote the section the rationale names (`python3 $S/doctrine.py "<heading>"`). Then ask again.
- **Drop**: silent.

### 8. Record
Start `fh-record-writer` with the `Agent` tool, giving it only the run folder and the skill folder. Put its commit body and PR description to the human in full with Approve, Drop and Other; write what they approve to `$R/record.md`.

### 9. Render
Write `$R/verdict.md`: three or four sentences - what is well homed, what is not, and the one finding with a silent consequence. Then `python3 $S/usage.py $R` and `python3 $S/render.py $R`.

### 10. Apply or post - gate
**Author mode.** Start `fh-scribe` with the `Agent` tool: the repo path, `$R/changes.md` and the recipes the repo's `AGENTS.md` names for formatting, linting and testing the touched files, including any it names for paths its linter excludes. Read the diff, confirm every skipped entry and run the touched tests yourself. Put the commit body from `record.md` in the commit. Commit nothing unless asked.

**Reviewer mode.** The comment is `review.md` above `<!-- review-end -->`: `sed '/<!-- review-end -->/,$d' $R/review.md > $R/review-comment.md`. Show the first lines and the cut, get a yes, then `gh pr comment <N> --body-file $R/review-comment.md`.

End with the path of `review.md`, `nvim -q <review.qf>` to step through the sites, the comment URL or the applied diffstat, the total tokens and the silent-consequence finding in one line.

### Calling a workflow
Pass `scriptPath` with the script's absolute path. If the tool refuses it, Read the script and pass its full text, unchanged, as `script`. The result names a saved script path; use it with `resumeFromRunId` to resume a run that stopped.

## Common rationalizations
| Rationalization | Reality |
|---|---|
| "I can see the answer, skip the arbiter" | You read one side of a split. The arbiter reads every site with the whole standard. |
| "The human's answer should be re-judged" | The human rules on intent, which no agent can check. Only a site they add gets rechecked. |
| "This finding is local, haiku can confirm it" | The detector chose the scope. A claim of absence or uniqueness is global whatever it looks like. |
| "The PR description is enough" | Only the text that survives the merge reaches the later reader; the repo profile's repo facts say which text that is. |

## Red flags
- A changed file, slice or `clusters.json` read before phase 4.
- A blind sweep told which files changed.
- The standard, a brief, the contract or a schema pasted into a prompt.
- A proposal before every AMBIGUOUS finding is clarified.
- A `file:line` in `review.md` that no refuter, arbiter or you checked.
- A repo exception reported as a finding.

## Verification
- [ ] `state.py next $R` names phase 10, and `state.py summary` shows no UNCERTAIN, SPLIT or unclarified AMBIGUOUS finding.
- [ ] `review.md` has a token row per agent with model and effort, and a total.
- [ ] `review.qf` has one line per site of every kept finding.
- [ ] Author mode: the scribe's commands and the touched tests passed, shown by their output.

## Hands off to
- `fact-homing-tmp` for a question the review raises about one fact.
