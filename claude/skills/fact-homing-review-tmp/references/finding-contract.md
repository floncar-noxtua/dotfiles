# Finding contract

Every fact-homing-review-tmp agent follows this file. Your brief gives your one question; this file gives the rules every answer shares. The structured output schema in the workflow script enforces the shape; this file says what goes in each field. The standard is the fact-homing-tmp skill's `references/fact-homing.md`: read the sections your brief names with `python3 <skill>/scripts/doctrine.py "<heading>"`, and the repo's exceptions and its own rules with `doctrine.py exceptions`. Run it from the repository your caller names.

## Ground rules

- **The repo's own rules win.** `doctrine.py exceptions` ends with the repo's `AGENTS.md` and `README.md`. Where either disagrees with the standard, an exception, this contract or your brief, judge by the repo file and name it in `exception`.
- **Read-only.** Edit nothing, create nothing. Answer only through the structured output. No prose report, no praise, no recap.
- **The code is the truth** for a fact about the code. Where prose, a name, a test or a claim disagrees with the code, the other thing is the defect. You never judge whether the code does what its author meant. A fact about the world or a convention is not checked against the code: check that its home ties it as "World facts" or "Conventions" says.
- **One finding, one fact.** Split a sentence that mixes a standing claim with an event, as "Facts" says. Two facts on one line are two findings.
- **Evidence, not memory.** Every site is a real `file:line` at HEAD, found with `rg -n`, `grep -n` or `sed -n`, its quote copied verbatim. A site you did not open is not a site.
- **Repo exceptions are not findings.** The repo profile, printed by `doctrine.py exceptions`, lists them. Where a ruling rests on one - CI blocks no merge, pytest collects no doctests - name its ticket in `exception` (or "no ticket") and judge the tie as the exception says. Never report the exception itself. No profile: say in the rationale where a ruling turns on a repo setting you could not check.
- **Rank, then cut.** At most 12 findings, highest consequence first. Say nothing about what you found fine.
- **Never guess intent.** When only the author can say whether two sites are one fact, or which one is meant, set `ambiguous` and write the `question`.

## Fields

| Field | What goes in it |
|---|---|
| `fact` | The fact in one sentence: "The hudoc chunk directory defaults to `output/hudoc_chunks`." |
| `fact_key` | The join key, in the first form that applies: the cluster key you were given; `path/module.py::Symbol` for a named definition; the literal in double quotes for a retyped value; a repo-relative path; a recipe name; `when <trigger>` for a procedure. Two agents describing one fact must produce one key, so never paraphrase it. |
| `lens` | Your brief names it. |
| `form`, `about`, `time`, `why` | The fact's kind, as "Facts" defines them: `state`, `rule` or `action`; about the `code`, the `world` or a `convention`; `standing`, `event`, `proposal` or `open-work`; whether it carries a why. |
| `sites` | Every place the fact is stated, read or should be pointed at, each with a role below. All of them, not a sample: the proposal is built from this list. |
| `home_now`, `ends`, `tie` | The row of the "Homes" table the fact sits in now, how that home ends and what ties it: `fails`, `displays`, `nothing`, or `cannot-go-stale` for an append-only home. |
| `consequence` | `silent`: drift breaks something with no error. `loud`: drift fails a build, test or run. `hygiene`: drift misleads a reader and breaks nothing. |
| `scope` | `local` when opening the listed sites settles the finding. `global` when it rests on sites it does not list: a claim of absence or uniqueness ("only caller", "no other copy", "never"), every copy or every step, or a proposed home that must not already exist. When unsure, `global`. A global finding gets two strong refuters; a wrong `local` gets one cheap one. |
| `step` | Where "The ladder" sends the fact: `record`, `ticket`, `1-delete`, `2-move`, `3-derive`, `4-watch`, `5-keep` or `accept-loss`. |
| `proposed_home` | The home afterwards, as `file:line` or a named form: "an import of `X` from `pkg.mod`", "a test in `tests/test_x.py`", "the commit body". |
| `recovery_cost` | For `4-watch`, `5-keep` and `accept-loss`: `cheap` or `expensive`, as "Balance" defines them. Otherwise `n/a`. |
| `exception` | The ticket of the repo exception the ruling rests on, or empty. |
| `rationale` | Two or three sentences: why this is a finding and what goes wrong if nothing changes. Name the section it rests on. The human reads it on "Explain"; refuters never see it. |
| `ambiguous`, `question` | Only when the code allows two answers and only intent decides. The question names the sites and the choice in one sentence. |

## Site roles

| Role | Meaning |
|---|---|
| `source` | The one place the fact lives, or should live |
| `copy` | A second statement of the fact |
| `consumer` | Code that reads the fact and would change with the fix |
| `test` | A test that is, or should become, the failing home |
| `pointer` | A line that should name where the fact lives without restating it |
| `prose` | A comment, docstring, document, skill or agent instruction line that states the fact |
| `record` | A commit body, PR description or ticket that holds an event |
