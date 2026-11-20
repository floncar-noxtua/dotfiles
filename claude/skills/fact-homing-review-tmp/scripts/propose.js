export const meta = {
  name: 'fact-homing-review-propose',
  description: 'fact-homing-review phase 6: recheck answers that added a site, then exact edits per group of files',
  phases: [
    { title: 'Recheck', detail: 'one refuter per human answer that named a site the finding did not list' },
    { title: 'Propose', detail: 'one fh-proposer per group of findings that share files' },
  ],
}

// args: { runDir, repo, skill, base, groups: [{ id, findings, files }], recheck: [ids], overrides }
// Built by `state.py plan-propose`. Groups share no file, so no two proposers edit one file. A recheck never
// overrules the human: what it finds reaches the proposer, and through the proposal's doubts, the human.

// The one home of each proposing agent's model and effort.
const ROSTER = {
  'refuter-recheck': { model: 'sonnet', effort: 'medium' },
  'fh-proposer': { model: 'sonnet', effort: 'medium' },
}

const SITE = {
  type: 'object',
  required: ['file', 'line', 'role'],
  properties: {
    file: { type: 'string' },
    line: { type: 'integer' },
    role: { enum: ['source', 'copy', 'consumer', 'test', 'pointer', 'prose', 'record'] },
  },
}
const EDIT = {
  type: 'object',
  required: ['file', 'action', 'anchor', 'content'],
  properties: {
    file: { type: 'string' },
    action: { enum: ['replace', 'insert_after', 'insert_before', 'delete', 'create'] },
    anchor: { type: 'string', description: 'Exact existing text the edit attaches to; empty only for create' },
    content: { type: 'string', description: 'Exact new text; empty for delete' },
  },
}
const PROPOSALS = {
  type: 'object',
  required: ['proposals'],
  properties: {
    proposals: {
      type: 'array',
      items: {
        type: 'object',
        required: ['finding_id', 'step', 'home', 'summary', 'sites', 'edits', 'tie_after'],
        properties: {
          finding_id: { type: 'string' },
          step: { enum: ['record', 'ticket', '1-delete', '2-move', '3-derive', '4-watch', '5-keep', 'accept-loss'] },
          home: { type: 'string' },
          summary: { type: 'string' },
          sites: { type: 'array', minItems: 1, items: SITE },
          edits: { type: 'array', items: EDIT },
          tie_after: { enum: ['fails', 'displays', 'nothing', 'cannot-go-stale'] },
          pointer: { type: 'string' },
          record: { type: 'string', description: 'For record and accept-loss: the commit body sentence' },
          ticket: { type: 'string', description: 'For ticket: the ticket text' },
          doubts: { type: 'string' },
        },
      },
    },
  },
}
const CHECK = {
  type: 'object',
  required: ['verdict', 'notes'],
  properties: { verdict: { enum: ['CONFIRMED', 'REFUTED', 'UNCERTAIN'] }, notes: { type: 'string' } },
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
const common = `Run folder: ${args.runDir}\nRepository: ${args.repo} (work from this directory)\nSkill: ${args.skill}\n`

phase('Recheck')
const checks = {}
await parallel((args.recheck || []).map(id => async () => {
  const r = await run(`recheck:${id}`, 'Recheck', 'refuter-recheck', 'fh-refuter',
    common + `Angle: answer\nRead the finding and the human's answer with: ${STATE} brief ${args.runDir} ${id} --angle answer`,
    CHECK)
  if (r) checks[id] = r
}))

async function propose(g, note) {
  const label = note ? `propose:${g.id}:retry` : `propose:${g.id}`
  const rechecked = g.findings.filter(id => checks[id])
    .map(id => `${id}: the sites the human added were rechecked: ${checks[id].verdict} - ${checks[id].notes}`)
  return run(label, 'Propose', 'fh-proposer', 'fh-proposer',
    common + `Findings: ${g.findings.join(', ')}. Read each with:\n` +
    g.findings.map(id => `${STATE} show ${args.runDir} ${id}`).join('\n') +
    (rechecked.length ? `\n${rechecked.join('\n')}\nA human answer wins; put a recheck that disagrees in doubts.` : '') +
    (note ? `\n\nYour previous answer was incomplete: ${note}` : ''), PROPOSALS)
}
function unlisted(p) {
  const listed = new Set(p.sites.map(s => s.file))
  return [...new Set(p.edits.map(e => e.file).filter(f => !listed.has(f)))]
}

phase('Propose')
const results = await pipeline(args.groups, async g => {
  let res = await propose(g)
  const bad = res ? res.proposals.filter(p => unlisted(p).length) : []
  const missing = res ? g.findings.filter(id => !res.proposals.some(p => p.finding_id === id)) : g.findings
  if (bad.length || missing.length) {
    const note = [
      ...bad.map(p => `${p.finding_id} edits ${unlisted(p).join(', ')} without listing it as a site`),
      ...(missing.length ? [`no proposal for ${missing.join(', ')}`] : []),
    ].join('; ')
    log(`${g.id}: ${note}; sending back once`)
    res = (await propose(g, note)) || res
  }
  const props = res ? res.proposals : []
  return {
    id: g.id,
    proposals: props.length,
    incomplete: props.filter(p => unlisted(p).length).map(p => p.finding_id)
      .concat(g.findings.filter(id => !props.some(p => p.finding_id === id))),
  }
})
return { roster, groups: results.filter(Boolean), rechecked: Object.keys(checks) }
