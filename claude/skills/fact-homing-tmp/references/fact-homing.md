# One fact, one home, tied by something that runs

This is the fact-homing standard: how to give each fact one home and keep that home true.

Code is a liability. So is every word written about it.

**Who this is for:** someone holding a fact, deciding where to put it or looking for one.

> - [**Facts**](#facts): every fact is a state, a rule or an action; about the code, the world or a convention; standing or an event; any can carry a why.
> - [**Homes**](#homes): maintained, append-only, freezing or expiring; tied by what runs, a check that *fails* or one that *displays*, else untied. The change that falsifies a fact fixes its home.
> - [**The code**](#the-cheapest-home-is-the-code) is the cheapest home: a declaration a tool consumes; a type, lint rule or test that fails; structure, names and messages, which display; last, a docstring or comment at the site. A document is what remains when none can carry the fact.
> - [**Ladder**](#the-ladder): record an event; ticket open work; take any other standing fact down delete, move, derive, watch, keep - stop at the first that works - or accept the loss.
> - [**Placing**](#placing): name the reader and the moment they need the fact, then point to it from where that reader starts. Cannot name the moment? It was written for the author, not a reader.
> - [**Balance**](#balance): cut redundancy, then verbosity; hold a fact only where a reader needs it and recovering it costs more than keeping it, else record the loss in the commit body.

## Facts

Every fact describes a **state** (what is true), a **rule** (a constraint the code must keep obeying) or an **action** (what to do).

Three things cut across all three kinds rather than forming a fourth.

- Any fact can carry a **why** (of this value, this rule, this order), the part no machine can derive.
- Any fact is about the **code**, about the **world** - a publisher's site, an API's limits, an upstream library's behavior - or a **convention**, how this team has decided to work. Only a fact about the code can be tied to the code; one about the world is tied only as [World facts](#world-facts) says; a convention as [Conventions](#conventions) says.
- Any fact is **standing**, claiming to be true now, or an **event**, true of one change, decision, incident or measurement. A standing fact needs a maintained home; an event needs an append-only one; a proposal is an event whose decision is pending, held in a freezing home until the decision. Split any fact that mixes the two: what a later change or the world could make false is standing; what was observed or weighed at one time is an event - a measurement is an event, the claim that it still holds is standing. Work not yet done is the one standing fact whose home ends with it: the ticket, which closes when the work is done.

## Homes

Homes differ in whether and how they end.

- A **maintained** home has no end - someone keeps it true or it rots.
- An **append-only** one cannot rot, because by convention nobody edits what is already there except to name what supersedes it.
- Between them sit the staging homes, which end at a marker. A **freezing** home becomes append-only at the marker. An **expiring** home leaves every reader's path at the marker; its text survives, but nobody reads it again.

Only maintained homes, and staging homes before their marker, can go **stale**, which is to say rot. An append-only record that contradicts today's code is not stale; it is **superseded**, and it describes an event that really happened.

A fact rarely starts where it belongs, so facts move: out of a home about to end, a standing fact toward a tied home, an event to an append-only one.

Homes that can go stale differ in what happens when their fact diverges from what it describes.

- Best is a home that ***fails***: a check that runs on every change breaks when the fact diverges, with no human involved. A test that calls the world fails on its own schedule rather than on a change.
- Next is one that merely ***displays*** the divergence to someone who may not look - a reviewer or author at change time, an operator at run time. A document, skill or agent instruction is **scoped** when its header, or a separate file that names it, lists the paths it describes in a format a tool reads. A tool, the **referee**, shows it to whoever makes or reviews a change under those paths. Declare each scope once; every referee reads that one declaration. A scoped home displays through its referee and only to those it reaches: a harness that loads path rules reaches its agent, and a human only through one.
- Worst is ***nothing***, which has no edge back to the code at all.

A home that can go stale **ties** a fact when it is what runs - a declaration a tool reads, which leaves no second copy to diverge - or when it fails on or displays the fact's divergence; otherwise it leaves the fact **untied**. A world fact is tied only as [World facts](#world-facts) says, whatever home holds it. Only a home that can go stale is tied or untied: an append-only one holds an event, not a standing fact, and never licenses deleting a standing copy.

| Home | Ends | Tie |
|---|---|---|
| Type, enum, assertion | Maintained | Fails where a type checker or the code runs; an `assert` only where assertions are enabled |
| Lint rule, import contract | Maintained | Fails on every violation in every file it checks |
| Test | Maintained | Fails where the runner collects it and neither skips it nor marks it a non-strict `xfail`; one that calls the world, on its schedule |
| Declaration a tool reads - config, project file, argument parser, service definition | Maintained | No copy to drift, since it is what the tool does; a wrong value fails only where something validates or uses it |
| Recipe, hook, CI step | Maintained | Fails where a hook or CI runs it |
| Generated file | As its source | Fails when CI regenerates it and finds a diff; no second source when gitignored |
| Assertive name | Maintained | Displays wherever the contradicting code is in view |
| Error, log or deprecation message | Maintained | Displays to whoever runs the code; a deprecation warning only where warnings are shown |
| Comment, docstring | Maintained | Displays when the change touches the lines around it |
| Scoped document or skill | Maintained | Displays only to those who work through the referee |
| Unscoped document or skill | Maintained | Nothing |
| Scoped agent instructions - a nested AGENTS.md, a rule with path globs | Maintained | Displays through the harness that loads them, to the agent touching the path; the paths they name fail where a test checks them |
| AGENTS.md, README | Maintained | Nothing for their prose - they span everything, so a scope would fire on every change; their [pointers](#pointers) fail on a rename where a test checks them |
| Confluence page, even one the repo links to | Maintained elsewhere | Nothing |
| PR description | Freezing at merge | Displays beside the diff until merge |
| Proposed ADR | Freezing at acceptance or rejection | Nothing |
| Ticket, review thread | Expiring - ticket at close, thread at merge | Nothing |
| Merged commit body, accepted or rejected ADR, dated log entry | Append-only | Cannot go stale |

A change that makes a standing fact false, or deletes what it describes, fixes or deletes the fact in its home in the same change, with every pointer to it. A record of an event stays; the next change writes a new one. A tie only tells the author which homes to check; an untied home is found by searching for the names the change touches.

## The cheapest home is the code

Code is readable when an agent new to it answers a question about it from its structure, its names and the facts homed in the repo. A question it cannot answer is a fact without a home or code to fix; a document that exists to explain unclear code is a patch over the real problem - fix the code instead.

Structure states things too. Where a file sits and what it is called asserts what belongs in it, as a variable name asserts what it holds, so prose describing the layout copies the tree. Names cost the reader nothing, and a name that asserts something checkable - a direction (`xml_to_udm`), a status (`unmapped_docs`), a unit (`timeout_seconds`) - shows its claim wherever it appears. `utils/`, `process()` and `data` assert nothing; prefer the assertive name. A domain term used across files is defined once, by the type or module that carries it; prose uses the name.

First ask whether the fact is *already* declared somewhere a tool consumes. A version, a pin, a port, a flag, a schema, a command - each is declared in something a tool reads, and that declaration is the home, because the tool does what it says: it cannot quietly disagree with what runs. Declarations live in code as well as config: the argument parser declares that a flag exists and what it defaults to, and the service definition declares the port. Point at it or generate from it; never retype it. A command is declared by its recipe: one that carries this repo's paths or flags gets a recipe, whichever tool it calls; one that carries none, such as `gh pr view` or a bare `git clone`, is written as its own docs show it. A secret is the exception: the code declares its name where it reads it, its value stays out of every committed home and where to fetch it is a [world fact](#world-facts).

The same holds inside the code: a constant, an enum's values or a schema's fields have one definition, and every other site imports or references it. Two statements are not copies where the second checks the first - a test's expected value - or where a tool reads a format that cannot reference the definition, such as a JSON mapping that must cover every field of a Pydantic model; there a test compares them.

A fact another repo also relies on has one owning repo, the one that produces it, which declares it; the other ties it with a contract test or a consumed package, never a retyped copy. A fact owned outside every repo - a spec page, a product decision - is a world fact the repo points at, with the date it was last checked where nothing calls it, as [World facts](#world-facts) says; the code that implements it is the tied home of what the code does, and a divergence between them is a ticket, not a silent edit of either. A fact the repo holds is not copied to Confluence; the page links to it.

Where nothing declares the fact yet, each kind of fact has a form nearest the code, and most of them fail:

| Fact | Form |
|---|---|
| A state of the code | A type, an enum, an assertion; for what the code does, a test |
| A rule the code must follow - a forbidden import, a banned call, a layering direction | A lint rule or an import contract for its shape; a test for its behavior |
| An action | A recipe, a hook, a CI step |
| A fact about the world | A test that calls the world, run on a schedule; if it cannot, the job that already calls it |
| The why of a standing fact | A message, or a name where it can state the reason; otherwise a comment or docstring |

Behavior goes furthest: only a test that calls the code and asserts on the result checks what it does, so behavior described in prose wants a test. Each check fails only where something runs it - a hook before every commit where it is installed, CI before every merge where its check is required - so "always run X before pushing" belongs in their configuration, not in prose.

## The ladder

When prose carries a fact, or would, or a second site retypes it, first sort it. An event is **recorded**. Work not yet done goes to its ticket, with a [pointer](#pointers) at the site. Any other standing fact works down five rungs and stops at the first that works. **A rung works when the fact survives it and stays findable by the reader who needs it** - not when the prose is gone. A rung that costs upkeep - new code such as a test, a lint rule or a generator, or a watch - works only if that upkeep costs less than [recovering the fact](#balance) would; otherwise go on down, and past the watch to [Balance](#balance).

| Step | Prose remains at the original site? | The fact lands in |
|---|---|---|
| Record (events) | No; a pointer where the record is an ADR | An append-only home; for a proposal, a freezing one and a ticket for its decision |
| Ticket (work not yet done) | A `TODO` naming it | The ticket |
| 1 - Delete | No | The tied maintained home that already carries it |
| 2 - Move | No | A form of [the code](#the-cheapest-home-is-the-code) |
| 3 - Derive | Generated | Text generated from its source |
| 4 - Watch | Yes | The prose itself, scoped to the paths it describes |
| 5 - Keep | Yes | The prose itself, untied, where it [earns its place](#balance) |
| Accept the loss | No | Nowhere; the record of the change that deletes it says what went |

**Record** an event: why this change, why this option over the alternatives, what happened in an incident. Write it into the home [Facts](#facts) gives it - the commit body or an ADR, as [Placing](#placing) picks, or a dated log entry for an event no change carries, such as an incident with no fix or a measurement - and delete the prose. A rejected option is recorded too, in a rejected ADR or in the commit body of the change that took the other path. A later change writes a new record rather than editing the old one; an ADR names the ADR that supersedes it. An event often carries a standing fact - the lesson of an incident, the reason a design still holds - and that part goes down the ladder: a comment where it sits beside one line, a scoped document naming the record where it spans files.

A commit body needs no pointer: `git blame` is one, and `git log -L` lists every commit that touched a range when a later edit hides the original. Blame cannot point at an absence: `git log -S` finds the commit that removed a string, but only for a reader who knows to look. Where the absence itself is the trap - "never retry here" - its standing part goes down the ladder, usually to a comment at the site, since nothing else can point at an absence. An ADR needs a pointer naming it: a comment at the site, or the scoped document that rests on it.

**Delete** the copy - available only where the code, or another tied maintained home, already carries the fact. A PR description displays only until merge and a ticket not at all, so neither licenses the delete. A copy in code is deleted the same way: import or reference the one definition. Deleting what nothing else carries is not rung 1; it is loss, which [Balance](#balance) covers. Where both copies are tied, keep the one other sites can reference and point the other at it. Where both are untied, rung 1 is not available: run the ladder on the fact once, put it at the home the ladder picks - a copy already there stays - and make every other copy a pointer or delete it.

**Move** it adjacent to the code, into the form [above](#the-cheapest-home-is-the-code) that fits its kind. Prefer a form that fails; where none fits, a name or a message, which display. A docstring or comment is the last form of this rung, not the first - a name is free to the reader, while a comment spends a scarce budget, and spending it on every displaced paragraph destroys the scarcity that makes comments worth stopping for. A doctest is a test whose example also teaches, once the runner collects it.

**Derive** it for a reader who needs the fact away from its source: generate the text from the source, or make a distant document's examples executable so the suite runs them - a block regenerated from a source file, reference built from the docstrings or the argument parser, a version or interpreter line read from the project file, release notes built from the commits. A generated file is either gitignored, or CI regenerates it and fails on any diff; if it can be hand-edited, there are two sources of truth again and no warning. TODO(ALL-10326): add a generator to the repo, so this rung has a tool to point at.

**Watch** it: surface the prose in a change's blast radius - the documents scoped to paths it touches, and with them the comments in its hunks that rung 2 left there - and ask whoever sees them, through a document's referee or in the diff, whether the change falsified them. This is the rung for a standing fact that no machine-readable source carries - most often rationale that spans files - which only a human's judgment checks. It is the last tied rung: the referee can ask, but nothing stops the answer from being wrong or ignored, and a watch costs maintenance for as long as the code lives. A scope no referee reads displays nothing: the home is untied, and the fact takes rung 5's test.

**Keep** it untied where nothing can tie it: no scope a referee reads fits, as with an AGENTS.md or README line, or nothing can call the world it describes. It stays only if all three hold: it serves a reader at a moment in [Placing](#placing); it passes the test its home sets, where the home has one, as [Agent instructions](#agent-instructions) and [README.md](#readmemd) do; and recovering it would [cost more](#balance) than keeping it true. Otherwise **accept the loss** and record it, as [Balance](#balance) says.

Apply the ladder **per fact, not per file.** Most documents spread across every step: paragraphs deleted, some moved into names, types and tests, one into a docstring, the example a doctest, the decision into a commit body, one paragraph of rationale left for the watch.

### World facts

A world fact is tied only by a call to the world: a test run on a schedule where calling is cheap and allowed, otherwise the job that already calls it, failing with the fact in its message. The world changes without a diff, so no watch sees it. Where nothing can call the world, keep the fact untied as [rung 5](#the-ladder) allows, dated so the reader can judge its age and check it again. Where someone outside the repo publishes the fact, the repo points at their page with the date it was checked; where only the repo observed it, the repo keeps it with when and where it was observed.

### Conventions

A convention is decided, not observed. One configured in a tool outside the repo - a merge setting, a branch rule - changes without a diff, so its current setting is a [world fact](#world-facts). Where a tool can check it, it becomes a hook, lint rule or CI step. Where none can, it is an action for the reader who must follow it: [agent instructions](#agent-instructions), or the document of the work it governs - scoped where that work has paths, untied where it spans the repo, as this document does. A convention that governs no path of this repo lives in the team's own page, which the repo links where the reader starts. A preference of one person is theirs: it lives in their user-level instructions or agent memory, never in a committed home.

### Pointers

A fact kept away from where its reader needs it requires a **pointer**: one line, where the reader would ask the question, naming where the fact went - a comment naming the ADR or scoped document, or a `TODO` naming the ticket for work not yet done. Without one, a fact in the right home is still unfindable, and the rung did not work.

A pointer names the home and says in a few words what is there, enough to decide whether to follow it; it does not repeat the content. It goes stale only when its target moves or ends, and a pointer into an expiring home dies with it. Where a pointer names a symbol or path, make a rename of it fail.

### People

A person's name is not a pointer. As the author it is `git blame` retyped; as an assignee it expires and belongs in a ticket.

Who is responsible for something - a source, a decision or access to a bucket - is not code ownership and changes without a diff, so it is a [world fact](#world-facts) kept on the team's Confluence page, never in a committed home. The repo links to that page from where the asker starts: the README for a newcomer, AGENTS.md or scoped agent instructions for an agent, the skill whose procedure needs the access, the error message of a job that fails without it or the scoped document of the work the question concerns.

The repo names no code owners: someone new to an area gets up to speed through an agent and the facts homed here, without the people who wrote the code.

### TODOs

A `TODO` carries two facts: the work not yet done, which lives in the ticket it names, and its trigger. The limitation the work would remove is standing now and runs the ladder; where nothing outside the repo gates the work, a strict `xfail` of the wanted behavior states it and fails once the work lands. The `TODO` goes when its ticket closes. Its trigger need not wait for a human: where it is machine-readable - an upstream fix, a version to drop, a date - it moves to rung 2 as a test that fails once the trigger fires. A trigger that fires without a change, such as a date, runs in a scheduled job rather than the merge gate. Keep that test out of code that runs in production, and name the file the `TODO` will delete in its failure message, so the failure is its own pointer. Tie test and site with a handle that fails rather than drifts: import the symbol being deleted, or where there is none, assert that the file exists.

### Sequences

A **sequence** is an ordered action. Run the ladder on each step. A step a script can perform becomes a recipe; a step something enforces, because skipping it makes a build, test or hook fail, is deleted. Where the order can be scripted too, the sequence becomes one recipe and nothing remains.

A sequence run once in the repo's life - a one-off migration, not a setup each newcomer repeats - does not become a recipe: nothing runs it again, so a recipe would only rot. Until it runs, it is work not yet done: where it can be scripted, the change that needs it adds the script, and the ticket tracks the run. Once it has run, delete the script and record the run in the commit that deletes it; `git log` keeps the script.

What remains of a recurring sequence - the steps that need judgment or access no script has - is a **procedure**, and its home is a [skill](#skills), written for the agent that runs it. A human reaches it through an agent, which runs it or explains the steps so the human can run them. Its trigger moves to rung 2 where it is machine-readable, as a `TODO`'s does, and stays in the skill only where it is not.

## Placing

Placing picks the home of what the ladder leaves as prose - a comment, docstring or message from rung 2, a record, a document under watch, a line kept untied - and of the pointers to it. It never overrides a rung: a fact that can fail lives where it fails. A fact the repo does not own - who is responsible for something, an outside spec - has no home here; Placing picks only where its pointer goes, by the same reader and moment.

**Name the reader and the moment they need this.** The moment does most of the work. Naming the reader alone does not discriminate - "a new engineer" justifies any paragraph you care to keep. The moment locates them: what they are doing, and where their attention is, when the need arises. A fact you cannot attach a moment to was written for the author's sense of completeness.

| Moment | Home | Read |
|---|---|---|
| *Working anywhere in this repo* - they are mid-session, with AGENTS.md loaded whether or not they needed it. | AGENTS.md | Every session |
| *About to edit under one path* - they are mid-session, in that subtree. | Scoped agent instructions - a nested AGENTS.md, a rule with path globs | When the agent touches the path |
| *Why is this value not the obvious one?* - they are in the file. | Comment | When its line is read |
| *Calling this without reading its body* - they have the signature in view. | Docstring | When the symbol is called |
| *Why did this fail, or what replaces this?* - they are running the code as it fails, logs or calls a path that is going away. | Error, log or deprecation message | When the code fails or warns |
| *Executing a procedure rather than reading it* - they are partway through, hands on the tools. | Skill | When the job starts |
| *This is not what it should be, and someone will fix it* - they are in the file, about to build on it. | Ticket, named by a pointer at the site | While its work is open |
| *Deciding whether to approve this change* - they are in the PR, with the diff open. | PR description; a review thread for what only the review needs, as [Commit bodies](#commit-bodies-and-pr-descriptions) says | While the change is reviewed |
| *Working on one source, contract or subsystem* - they are about to change it or to read what it produces. | Scoped document in `docs/` | Before a change under its paths |
| *About to change how the parts of the system relate* - they are planning a change across subsystems. | Architecture document | Before a change across subsystems |
| *Deciding whether to adopt this, setting it up or consuming its output* - they have not worked in it yet. | README.md | Once per newcomer |
| *Why did this change?* - they are in `git blame`. | Commit body | When someone asks why |
| *Why this option and not the alternatives?* - they are about to undo a decision or to reopen it. | ADR where reversing it would touch several files, another team or stored data; otherwise the commit body | When someone asks why |
| *What happened, and when?* - they are investigating something that looks like a repeat. | Dated log entry | When someone asks what happened |

Take the row that fits. Where two fit, prefer the tied home; if both are tied or both untied, the one nearer the code. Nearness displays only when a change lands next to it; it is not a check.

**Progressive disclosure.** Homes are layers, one per moment above. Each layer holds what its reader needs at that moment, never a summary of another layer: a summary is a second copy, a [pointer](#pointers) is one line. Put the fact in the layer of its moment and point to it from where that reader starts; a fact no chain of pointers reaches is not homed, whatever file holds it. Prose that spans the system has no single site to point from, so AGENTS.md or the README points to it. A summary at the top of the same file is the one exception: a change to a section can miss it, so keep each line short enough to check against its section at a glance.

The homes that need more than a row follow. Their formats are not defined here. TODO(ALL-10223): name the document that defines the commit body and PR description formats. TODO(ALL-10221): name the one that defines the ADR and log entry formats and where they live. TODO(ALL-10220): name the one that defines how a scope is declared and what the referee does.

### Commit bodies and PR descriptions

Neither the reviewer nor a later reader has the author's context. Skip what the diff shows. Write what it cannot - why the change exists, what was left out and what was deleted with the [cost of recovering it](#balance) - once, in whichever text survives the merge as the commit body; the other points to it. Write it for the reader who reaches the commit after the merge, through `git blame` or `git log`: a sentence that reader would not need does not belong. Where the core of the change sits, what is mechanical and how it was verified pass that test; a reading order, a question to reviewers and review bookkeeping fail it and go in a review thread, which ends at merge. These are events. Work left out that someone should still do goes to its ticket; a standing fact goes in a maintained home, because nobody maintains the description.

### Architecture documents

No single file shows how the parts relate. Write how they relate and why they are split that way; what each file does is the code's job; a decision and its alternatives are a record the document names; the order to move in is a [sequence](#sequences). Scope it to the modules whose boundaries it describes, not the whole tree, so the watch knows which diffs might falsify it. A diagram of how the parts relate is [derived](#the-ladder) where a tool can draw it - an import graph, the orchestrator's DAG view, an entity diagram from the models. One drawn by hand is the document's prose in another form: keep it as text source such as Mermaid, so a change to it shows in the diff, never as an image alone.

### Agent instructions

Agent instructions are AGENTS.md, loaded in full every session, and scoped instructions - a nested AGENTS.md or a rule with path globs, such as Claude Code's `.claude/rules/` - loaded when the agent touches their paths. Both are acted on without a check, so a stale line misleads every session that loads it and nothing fails. Keep a line only if the agent would act differently without it and cannot cheaply see the fact where it stands. A stack list, a directory tree and a command line fail that test: they copy the project file, the tree and the `justfile`, which the agent reads anyway. What passes is rules no tool checks yet, conventions the language does not imply and domain facts whose violation does damage far from the file at hand. A rule a tool enforces gets one line naming the tool. A line that matters under one path goes in scoped instructions for that path, not in AGENTS.md; a fact that needs more than a line goes in a document they point to, scoped where it has paths.

### Skills

A skill holds the steps of a procedure in the order they run and the judgment between them - what no single recipe can hold - for the agent executing it. It holds actions, not states or rules: a state or rule a step relies on stays in its home, and the step points to it. Scope it to the files its steps name or rely on, not the trees they write into. It names a recipe rather than spelling out its command, as [declarations](#the-cheapest-home-is-the-code) says, because a retyped path or flag that is outdated but still valid runs without complaint, against the wrong target. A skill needs no companion document for humans: an agent explains it from the skill and the facts homed in the repo, and what neither holds is a standing fact that runs the ladder.

### README.md

A README answers what this is, for whom and what it produces, then how to get from clone to a first run, then names the homes that take over - the `justfile`, AGENTS.md, `docs/`, the architecture document. Leave out what helps only someone already working in the code; that is where most README paragraphs come from. Name the recipe, the script or the project file rather than retyping what it declares, as [declarations](#the-cheapest-home-is-the-code) says.

## Balance

Brevity is the *result* of applying the rule, not a target in itself. Two passes produce it, in this order:

1. **Redundancy** - apply [rung 1](#the-ladder) to each sentence, including its rule for untied copies.
2. **Verbosity** - is what remains said in the fewest words? Omit needless words.

Run redundancy first because editing prose you were about to delete is wasted work.

Taken alone, both passes argue for the cut, so before deleting a fact nothing else carries, and before watching or keeping one, **ask what recovering it would cost**: cheap where a reader rebuilds it from the code or a test in minutes, expensive where rebuilding needs an outside party, an incident, a production run or someone who has left.
Upkeep is not writing the check: it is each alarm that costs a human look and the time someone spends deciding whether it is real. A false alarm fires while the fact still holds - a flaky or world-calling test, a scope wider than the prose it watches; a deliberate change fires rightly but still leaves someone to confirm the edit to the test or the watched prose.
A high cost justifies holding the fact - under a watch where a scope a referee reads fits it, untied where none does.
A low one means accepting the loss, deliberately and once: the body of the commit that deletes the prose names what went and why recovering it is cheap. Unrecorded, the deletion looks like nobody found a home, and the next reader pays to reopen the question.

Both passes run at corpus scale too. Every untied document is a standing cost: each earns its place by serving a reader at a moment in [Placing](#placing), and one that cannot is deleted rather than left to dilute the ones that can. **A corpus nobody can navigate might as well not exist.**
