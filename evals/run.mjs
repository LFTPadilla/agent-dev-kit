// Deterministic eval: does semgrep catch the planted bugs without flagging the control?
// Usage: node evals/run.mjs   (requires `semgrep` on PATH: pipx install semgrep)
//
// This scores ONLY the deterministic SAST floor. The LLM agents (pr-review,
// security-checklist) are scored separately by the manual PROTOCOL.md — they are
// expected to catch what semgrep misses (e.g. the React dependency bug).
import { execSync } from 'node:child_process'
import { readFileSync } from 'node:fs'

const cases = JSON.parse(readFileSync(new URL('./cases.json', import.meta.url)))

let raw = ''
try {
  raw = execSync('semgrep --config auto --json evals/cases', { encoding: 'utf8' })
} catch (e) {
  raw = e.stdout || '' // semgrep exits non-zero when it finds something
}
const results = (JSON.parse(raw || '{}').results) || []
const flagged = new Set(results.map((f) => f.path.split('/').pop()))

let tp = 0, fn = 0, fp = 0, tn = 0
for (const c of cases) {
  const hit = flagged.has(c.file)
  if (c.plantedBug) hit ? tp++ : fn++
  else hit ? fp++ : tn++
  console.log(`${hit ? 'FLAG ' : '  -  '} ${c.file}${c.plantedBug ? '' : '  (control)'}`)
}
const recall = tp + fn ? (tp / (tp + fn)) * 100 : 0
console.log(`\nsemgrep floor: recall ${recall.toFixed(0)}% (${tp}/${tp + fn} planted caught) · false positives ${fp}/${fp + tn} controls`)
console.log('Misses are expected — they are the cases the LLM review layer must cover. See PROTOCOL.md.')
