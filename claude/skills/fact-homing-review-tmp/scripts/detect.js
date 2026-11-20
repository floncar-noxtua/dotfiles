export const meta = {
  name: 'fact-homing-review-detect',
  description: 'fact-homing-review phase 2: cluster judges, diff lenses and blind sweeps, one question each',
  phases: [{ title: 'Detect', detail: 'one agent per cluster, slice or sweep' }],
}

// args: { runDir, repo, skill, agents, base, subjectArea, items: [{ agent, slice?, cluster? }], overrides }
// Built by `state.py plan-detect`; never typed by hand. Returns counts only: the findings stay in the
// agents' transcripts until `collect.py detect` copies them into the run folder.

// The one home of each detector's model and effort. Haiku only where the check is local and shaped.
const ROSTER = {
  'fh-ssot-judge': { model: 'sonnet', effort: 'medium' },
  'fh-sweep-code': { model: 'sonnet', effort: 'medium' },
  'fh-sweep-prose': { model: 'sonnet', effort: 'low' },
  'fh-sweep-declarations': { model: 'haiku', effort: 'low' },
  'fh-prose-at-site': { model: 'sonnet', effort: 'low' },
  'fh-names': { model: 'haiku', effort: 'low' },
  'fh-declarations': { model: 'haiku', effort: 'low' },
  'fh-tests': { model: 'sonnet', effort: 'low' },
  'fh-todos': { model: 'haiku', effort: 'low' },
  'fh-docs': { model: 'sonnet', effort: 'medium' },
  'fh-claims': { model: 'sonnet', effort: 'medium' },
  'fh-procedures': { model: 'sonnet', effort: 'medium' },
  'diff-all': { model: 'sonnet', effort: 'low' },
}
// Judging meaning or a whole procedure is where a cheap model confirms what it did not check.
const NEVER_HAIKU = new Set(['fh-ssot-judge', 'fh-claims', 'fh-procedures', 'fh-docs'])
const BLIND = new Set(['fh-sweep-code', 'fh-sweep-prose', 'fh-sweep-declarations'])
const DIFF_ALL_BRIEFS = ['fh-prose-at-site', 'fh-names', 'fh-declarations', 'fh-tests', 'fh-todos', 'fh-docs']

const SITE = {
  type: 'object',
  required: ['file', 'line', 'role', 'quote'],
  properties: {
    file: { type: 'string' },
    line: { type: 'integer' },
    role: { enum: ['source', 'copy', 'consumer', 'test', 'pointer', 'prose', 'record'] },
    quote: { type: 'string' },
  },
}
const FINDING = {
  type: 'object',
  required: ['fact', 'fact_key', 'lens', 'form', 'about', 'time', 'why', 'sites', 'home_now', 'ends', 'tie',
    'consequence', 'scope', 'step', 'proposed_home', 'rationale'],
  properties: {
    fact: { type: 'string' },
    fact_key: { type: 'string' },
    lens: { enum: ['ssot', 'prose', 'name', 'declaration', 'test', 'todo', 'claim', 'procedure', 'doc'] },
    form: { enum: ['state', 'rule', 'action'] },
    about: { enum: ['code', 'world', 'convention'] },
    time: { enum: ['standing', 'event', 'proposal', 'open-work'] },
    why: { type: 'boolean' },
    sites: { type: 'array', minItems: 1, items: SITE },
    home_now: { type: 'string' },
    ends: { enum: ['maintained', 'append-only', 'freezing', 'expiring'] },
    tie: { enum: ['fails', 'displays', 'nothing', 'cannot-go-stale'] },
    consequence: { enum: ['silent', 'loud', 'hygiene'] },
    scope: { enum: ['local', 'global'] },
    step: { enum: ['record', 'ticket', '1-delete', '2-move', '3-derive', '4-watch', '5-keep', 'accept-loss'] },
    proposed_home: { type: 'string' },
    recovery_cost: { enum: ['cheap', 'expensive', 'n/a'] },
    exception: { type: 'string' },
    rationale: { type: 'string' },
    ambiguous: { type: 'boolean' },
    question: { type: 'string' },
  },
}
const FINDINGS = {
  type: 'object',
  required: ['findings'],
  properties: { findings: { type: 'array', maxItems: 12, items: FINDING } },
}

const roster = []
function settings(agent) {
  const base = ROSTER[agent]
  const o = (args.overrides || {})[agent] || {}
  const s = { model: o.model || base.model, effort: o.effort || base.effort }
  if (NEVER_HAIKU.has(agent) && s.model === 'haiku') s.model = 'sonnet'
  return s
}

const common = `Run folder: ${args.runDir}\nRepository: ${args.repo} (work from this directory)\nSkill: ${args.skill}\n`
function prompt(item) {
  if (item.agent === 'fh-ssot-judge') {
    return common + `Your cluster: ${item.cluster}. Read it with:\n` +
      `jq '.clusters[] | select(.id=="${item.cluster}")' ${args.runDir}/clusters.json\n` +
      `Use the cluster's fact_key verbatim as the fact_key of your findings.`
  }
  if (BLIND.has(item.agent)) {
    return common + `Subject area: ${args.subjectArea}\n` +
      `You are blind to the change. Do not run git diff, git log or git show, and do not open the run folder.`
  }
  const slice = `Your slice: ${args.runDir}/${item.slice}\nDiff range: ${args.base}...HEAD`
  if (item.agent === 'diff-all') {
    return common + slice + `\nThe diff is small, so you answer several briefs at once. Read ` +
      `${args.skill}/references/finding-contract.md, then each of these briefs and answer its question for this ` +
      `slice, in its own terms, setting each finding's lens as that brief says: ` +
      DIFF_ALL_BRIEFS.map(b => `${args.agents}/${b}.md`).join(', ') + '.'
  }
  return common + slice
}
function wellFormed(res) {
  return res && res.findings.every(f => f.sites.every(s => s.line > 0 && s.quote && s.quote.trim()))
}

phase('Detect')
const counts = await parallel(args.items.map(item => async () => {
  const tag = item.cluster || item.slice?.replace(/^slices\//, '').replace(/\.txt$/, '') || item.agent
  const label = item.agent === 'fh-ssot-judge' ? `judge:${item.cluster}` : `detect:${tag}`
  const s = settings(item.agent)
  const opts = { label, phase: 'Detect', schema: FINDINGS, ...s }
  if (item.agent !== 'diff-all') opts.agentType = item.agent
  roster.push({ label, agent: item.agent, phase: 'Detect', ...s })
  let res = await agent(prompt(item), opts)
  if (!wellFormed(res) && s.model === 'haiku') {
    log(`${label}: Haiku result without file:line quotes, rerunning on Sonnet`)
    const rerun = { ...opts, label: `${label}:rerun`, model: 'sonnet' }
    roster.push({ label: rerun.label, agent: item.agent, phase: 'Detect', model: 'sonnet', effort: s.effort })
    res = await agent(prompt(item), rerun)
  }
  return res ? res.findings.length : 0
}))
const total = counts.filter(Boolean).reduce((a, b) => a + b, 0)
log(`${total} findings from ${args.items.length} agents`)
return { roster, findings: total }
