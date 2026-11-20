export const meta = {
  name: 'fact-homing-review-verify',
  description: 'fact-homing-review phase 3: refute every finding by its route, arbitrate splits, merge one fact found twice',
  phases: [
    { title: 'Verify', detail: 'light: one haiku refuter that may escalate; strong: two sonnet refuters' },
    { title: 'Arbitrate', detail: 'one opus arbiter per split or uncertain finding' },
    { title: 'Merge', detail: 'one judge per group of surviving findings that share a site' },
  ],
}

// args: { runDir, repo, skill, base, items: [{ id, route: 'light'|'strong' }], overrides }
// Built by `state.py plan-verify`. Each agent reads its finding with `state.py brief`, which leaves out the
// detector's rationale. Returns verdicts and the labels of the agents whose outputs `collect.py verify` reads.

// The one home of each verifier's model and effort.
const ROSTER = {
  'refuter-light': { model: 'haiku', effort: 'low' },
  'refuter-strong': { model: 'sonnet', effort: 'medium' },
  'fh-arbiter': { model: 'opus', effort: 'high' },
  'fh-merge-judge': { model: 'sonnet', effort: 'medium' },
}

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
const CORRECTED = {
  type: 'object',
  required: ['fact', 'sites'],
  properties: {
    fact: { type: 'string' },
    sites: { type: 'array', minItems: 1, items: SITE },
    tie: { enum: ['fails', 'displays', 'nothing', 'cannot-go-stale'] },
    scope: { enum: ['local', 'global'] },
    step: { enum: ['record', 'ticket', '1-delete', '2-move', '3-derive', '4-watch', '5-keep', 'accept-loss'] },
    proposed_home: { type: 'string' },
  },
}
const VOTE = {
  type: 'object',
  required: ['verdict', 'notes', 'corrected'],
  properties: {
    verdict: { enum: ['CONFIRMED', 'REFUTED', 'UNCERTAIN', 'AMBIGUOUS', 'ESCALATE'] },
    notes: { type: 'string' },
    question: { type: 'string' },
    corrected: CORRECTED,
  },
}
const RULING = {
  type: 'object',
  required: ['verdict', 'notes', 'corrected'],
  properties: {
    verdict: { enum: ['CONFIRMED', 'REFUTED', 'AMBIGUOUS'] },
    notes: { type: 'string' },
    question: { type: 'string' },
    corrected: CORRECTED,
  },
}
const MERGES = {
  type: 'object',
  required: ['groups'],
  properties: {
    groups: {
      type: 'array',
      items: {
        type: 'object',
        required: ['keep', 'merge', 'why'],
        properties: { keep: { type: 'string' }, merge: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } },
      },
    },
  },
}

const roster = []
function settings(role) {
  const o = (args.overrides || {})[role] || {}
  return { model: o.model || ROSTER[role].model, effort: o.effort || ROSTER[role].effort }
}
async function run(label, phaseName, role, agentType, prompt, schema) {
  const s = settings(role)
  roster.push({ label, agent: role, phase: phaseName, ...s })
  return agent(prompt, { label, phase: phaseName, agentType, schema, ...s })
}

const STATE = `python3 ${args.skill}/scripts/state.py`
const common = `Run folder: ${args.runDir}\nRepository: ${args.repo} (work from this directory)\nSkill: ${args.skill}\n` +
  `Diff range: ${args.base}...HEAD\n`
const refute = (id, angle, role) => run(`verify:${id}:${angle}${role === 'refuter-strong' ? '' : ':light'}`, 'Verify', role,
  'fh-refuter', common + `Angle: ${angle}\nRead your finding with: ${STATE} brief ${args.runDir} ${id} --angle ${angle}` +
  (role === 'refuter-light' ? `\nYou are the light refuter: return ESCALATE when the verdict needs more than the listed sites.` : ''),
  VOTE)

function combine(votes) {
  const v = votes.filter(Boolean).map(x => x.verdict)
  if (!v.length) return 'UNCERTAIN'
  if (v.includes('CONFIRMED') && v.includes('REFUTED')) return 'SPLIT'
  if (v.includes('REFUTED')) return 'REFUTED'
  if (v.includes('AMBIGUOUS')) return 'AMBIGUOUS'
  if (v.includes('UNCERTAIN')) return 'UNCERTAIN'
  return 'CONFIRMED'
}

phase('Verify')
const verified = await pipeline(args.items, async item => {
  const labels = []
  let votes = []
  if (item.route === 'light') {
    const v = await refute(item.id, 'holds', 'refuter-light')
    labels.push(`verify:${item.id}:holds:light`)
    if (v && v.verdict !== 'ESCALATE') votes = [v]
    else log(`${item.id}: light refuter ${v ? 'escalated' : 'returned nothing'}, going strong`)
  }
  if (!votes.length) {
    votes = await parallel(['holds', 'home'].map(angle => () => refute(item.id, angle, 'refuter-strong')))
    labels.push(`verify:${item.id}:holds`, `verify:${item.id}:home`)
  }
  let verdict = combine(votes)
  let corrected = votes.find(v => v && v.corrected)?.corrected
  if (verdict === 'SPLIT' || verdict === 'UNCERTAIN') {
    const notes = votes.filter(Boolean).map((v, i) => `Refuter ${i + 1}: ${v.verdict} - ${v.notes}`).join('\n')
    const r = await run(`arbiter:${item.id}`, 'Arbitrate', 'fh-arbiter', 'fh-arbiter',
      common + `Read the finding with: ${STATE} brief ${args.runDir} ${item.id} --angle home\nThe refuters disagreed or could not tell:\n${notes}`,
      RULING)
    labels.push(`arbiter:${item.id}`)
    if (r) { verdict = r.verdict; corrected = r.corrected }
  }
  return { id: item.id, verdict, labels, sites: corrected ? corrected.sites : [] }
})

// Two lenses often find one fact under two keys. The refuters have completed every site list by now, so
// shared sites are the signal; a judge rules on meaning, since two facts can share one line.
const live = verified.filter(r => r && r.verdict !== 'REFUTED')
const owner = new Map()
const parent = new Map(live.map(r => [r.id, r.id]))
const root = x => { while (parent.get(x) !== x) x = parent.get(x); return x }
for (const r of live) for (const s of r.sites) {
  if (s.role === 'consumer') continue
  const k = `${s.file}:${s.line}`
  if (owner.has(k)) parent.set(root(r.id), root(owner.get(k)))
  else owner.set(k, r.id)
}
const comps = new Map()
for (const r of live) { const k = root(r.id); comps.set(k, [...(comps.get(k) || []), r.id]) }
const groups = [...comps.values()].filter(c => c.length > 1)
phase('Merge')
const merges = (await parallel(groups.map((ids, i) => () => run(`merge:m${i + 1}`, 'Merge', 'fh-merge-judge', 'fh-merge-judge',
  common + `Findings that share a site: ${ids.join(', ')}. Read each with:\n` +
  ids.map(id => `${STATE} brief ${args.runDir} ${id} --angle home`).join('\n'), MERGES))))
  .filter(Boolean).flatMap(m => m.groups)
  .filter(g => g.merge.length && [g.keep, ...g.merge].every(id => groups.some(c => c.includes(id))))

const tally = {}
for (const r of verified.filter(Boolean)) tally[r.verdict] = (tally[r.verdict] || 0) + 1
log(`verdicts: ${Object.entries(tally).map(([k, v]) => `${v} ${k}`).join(', ')}; ${merges.length} merges`)
return {
  roster,
  findings: verified.filter(Boolean).map(({ id, verdict, labels }) => ({ id, verdict, labels })),
  merges: merges.map(({ keep, merge, why }) => ({ keep, merge, why })),
}
