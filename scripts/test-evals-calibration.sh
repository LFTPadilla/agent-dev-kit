#!/usr/bin/env bash
# Contract tests for the evals calibration bench (evals/calibration/).
#
# The bench never calls a model. These tests prove that it reads run files,
# joins them with the taxonomy, and reports the cheapest model that passes
# each task class. All fixtures are marked synthetic.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH="$ROOT/evals/calibration/run.mjs"
TAXONOMY="$ROOT/evals/calibration/taxonomy.json"
CASES="$ROOT/evals/cases.json"

[ -f "$BENCH" ] || { echo 'FAIL evals/calibration/run.mjs not found'; exit 1; }
[ -f "$TAXONOMY" ] || { echo 'FAIL evals/calibration/taxonomy.json not found'; exit 1; }

scratch="$(mktemp -d)"
cleanup() { rm -rf "$scratch"; }
trap cleanup EXIT

fail() { printf 'FAIL %s\n' "$1"; exit 1; }

# --- 1. the taxonomy labels every case exactly once, in a known class --------
node - "$CASES" "$TAXONOMY" <<'JS'
const [casesFile, taxonomyFile] = process.argv.slice(2)
const cases = JSON.parse(require('node:fs').readFileSync(casesFile, 'utf8'))
const taxonomy = JSON.parse(require('node:fs').readFileSync(taxonomyFile, 'utf8'))
const problems = []
const labelled = Object.keys(taxonomy.cases)
if (cases.length !== labelled.length) {
  problems.push(`cases.json has ${cases.length} cases, taxonomy labels ${labelled.length}`)
}
for (const c of cases) {
  const entry = taxonomy.cases[c.file]
  if (!entry) { problems.push(`no class for ${c.file}`); continue }
  if (!taxonomy.classes[entry.class]) problems.push(`${c.file} names unknown class ${entry.class}`)
  if (c.plantedBug === false && entry.class !== 'fp-discipline') {
    problems.push(`${c.file} is a clean control but its class is ${entry.class}`)
  }
  if (c.plantedBug === true && entry.class === 'fp-discipline') {
    problems.push(`${c.file} is planted but its class is fp-discipline`)
  }
}
for (const file of labelled) {
  if (!cases.some((c) => c.file === file)) problems.push(`taxonomy labels unknown case ${file}`)
}
if (problems.length) { problems.forEach((p) => console.log(`FAIL ${p}`)); process.exit(1) }
console.log(`ok taxonomy labels all ${cases.length} cases`)
JS

# --- 2. the empty report is honest: no runs, no recommendation ---------------
mkdir -p "$scratch/no-runs"
node "$BENCH" --runs-dir "$scratch/no-runs" --out-dir "$scratch/empty" >/dev/null
[ -f "$scratch/empty/report.json" ] || fail 'empty run wrote no report.json'
node - "$scratch/empty/report.json" <<'JS'
const report = JSON.parse(require('node:fs').readFileSync(process.argv[2], 'utf8'))
const problems = []
if (report.runs.length !== 0) problems.push('expected zero runs read')
for (const row of report.classes) {
  if (row.recommendation !== null) problems.push(`${row.class} recommends ${row.recommendation} with no runs`)
}
if (!report.warnings.some((w) => w.includes('No run files found'))) problems.push('missing the no-runs warning')
if (problems.length) { problems.forEach((p) => console.log(`FAIL ${p}`)); process.exit(1) }
console.log(`ok empty report recommends nothing across ${report.classes.length} classes`)
JS

# --- 3. a synthetic fixture produces the expected class-to-model picks -------
node "$BENCH" --runs "$ROOT/evals/calibration/runs/example-synthetic.json" --out-dir "$scratch/example" >/dev/null
node - "$scratch/example/report.json" <<'JS'
const report = JSON.parse(require('node:fs').readFileSync(process.argv[2], 'utf8'))
const pick = Object.fromEntries(report.classes.map((row) => [row.class, row.recommendation]))
const expected = {
  'pattern-scan': 'example/cheap-model',
  'taint-trace': 'example/frontier-model',
  'semantic-intent': 'example/mid-model',
  'state-reasoning': 'example/frontier-model',
  'fp-discipline': 'example/cheap-model'
}
const problems = []
for (const [name, model] of Object.entries(expected)) {
  if (pick[name] !== model) problems.push(`${name}: expected ${model}, got ${pick[name]}`)
}
if (report.synthetic !== true) problems.push('report did not carry the synthetic flag')
if (!report.warnings.some((w) => w.startsWith('SYNTHETIC DATA'))) problems.push('missing the synthetic warning')
if (problems.length) { problems.forEach((p) => console.log(`FAIL ${p}`)); process.exit(1) }
console.log('ok synthetic fixture picks the cheapest passing model per class')
JS

# --- 4. the pass bar moves the pick ----------------------------------------
node "$BENCH" --runs "$ROOT/evals/calibration/runs/example-synthetic.json" --min-pass 0.3 --out-dir "$scratch/relaxed" >/dev/null
node - "$scratch/relaxed/report.json" "$scratch/example/report.json" <<'JS'
const [relaxed, strict] = process.argv.slice(2).map((f) => JSON.parse(require('node:fs').readFileSync(f, 'utf8')))
const classOf = (report) => Object.fromEntries(report.classes.map((row) => [row.class, row.recommendation]))
const loose = classOf(relaxed)
const tight = classOf(strict)
const problems = []
if (loose['state-reasoning'] !== 'example/mid-model') {
  problems.push(`relaxed bar should allow the cheaper model on state-reasoning, got ${loose['state-reasoning']}`)
}
if (tight['state-reasoning'] !== 'example/frontier-model') {
  problems.push(`strict bar should keep the strong model on state-reasoning, got ${tight['state-reasoning']}`)
}
if (problems.length) { problems.forEach((p) => console.log(`FAIL ${p}`)); process.exit(1) }
console.log('ok --min-pass changes the pick')
JS

# --- 5. a run that is missing cost falls back and says so -------------------
node - "$scratch/nocost.json" "$ROOT/evals/calibration/runs/example-synthetic.json" <<'JS'
const fs = require('node:fs')
const source = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'))
delete source.synthetic
for (const model of source.models) { delete model.price_in_per_mtok; delete model.price_out_per_mtok }
for (const result of source.results) { delete result.tokens_in; delete result.tokens_out }
fs.writeFileSync(process.argv[2], JSON.stringify(source, null, 2))
JS
node "$BENCH" --runs "$scratch/nocost.json" --out-dir "$scratch/nocost" >/dev/null
node - "$scratch/nocost/report.json" <<'JS'
const report = JSON.parse(require('node:fs').readFileSync(process.argv[2], 'utf8'))
const problems = []
for (const row of report.classes) {
  if (row.recommendationCostPerCase !== null) problems.push(`${row.class} invented a cost`)
  if (row.confidence !== 'cost-unknown') problems.push(`${row.class} confidence is ${row.confidence}, expected cost-unknown`)
}
if (problems.length) { problems.forEach((p) => console.log(`FAIL ${p}`)); process.exit(1) }
console.log('ok a run without cost reports cost-unknown, not a made-up price')
JS

# --- 5b. a run that covers only part of a class reports partial -------------
node - "$scratch/partial.json" "$ROOT/evals/calibration/runs/example-synthetic.json" <<'JS'
const fs = require('node:fs')
const source = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'))
source.label = 'partial-coverage'
// Drop case 03, so the pattern-scan class is covered 3 of 4.
source.results = source.results.filter((r) => r.case !== '03-n-plus-one.ts')
fs.writeFileSync(process.argv[2], JSON.stringify(source, null, 2))
JS
node "$BENCH" --runs "$scratch/partial.json" --out-dir "$scratch/partial" >/dev/null
node - "$scratch/partial/report.json" <<'JS'
const report = JSON.parse(require('node:fs').readFileSync(process.argv[2], 'utf8'))
const row = report.classes.find((r) => r.class === 'pattern-scan')
const problems = []
if (row.confidence !== 'partial') problems.push(`expected partial, got ${row.confidence}`)
if (row.recommendationCostPerCase !== null) problems.push('a partial pick must not claim a cost ranking')
if (!report.warnings.some((w) => w.includes('partial result'))) problems.push('missing the partial warning')
if (problems.length) { problems.forEach((p) => console.log(`FAIL ${p}`)); process.exit(1) }
console.log('ok a partial class reports partial, not a cost verdict')
JS

# --- 6. malformed runs are rejected with exit code 2 ------------------------
# Output goes to a file first: `grep -q` closes the pipe early, and pipefail
# would then report the runner's SIGPIPE instead of the test result.
reject_check() {
  local label="$1" fixture="$2" pattern="$3"
  node "$BENCH" --runs "$fixture" --out-dir "$scratch/bad" > "$scratch/reject.log" 2>&1 && fail "$label was accepted"
  grep -q "$pattern" "$scratch/reject.log" || fail "$label: expected message missing: $pattern"
  echo "ok $label is rejected"
}

printf '%s' '{"format":"adk-eval-run/1","label":"bad","models":[{"id":"m"}],"results":[{"model":"m","case":"01-sql-injection.ts","finding":null}]}' > "$scratch/unfilled.json"
reject_check 'an unfilled finding' "$scratch/unfilled.json" 'finding must be true or false'

printf '%s' '{"format":"adk-eval-run/1","label":"bad","models":[{"id":"m"}],"results":[{"model":"ghost","case":"01-sql-injection.ts","finding":true}]}' > "$scratch/ghost.json"
reject_check 'an undeclared model' "$scratch/ghost.json" 'undeclared model ghost'

printf '%s' '{"format":"adk-eval-run/1","label":"bad","models":[{"id":"m"}],"results":[{"model":"m","case":"99-nope.ts","finding":true}]}' > "$scratch/ghostcase.json"
reject_check 'an unknown case' "$scratch/ghostcase.json" 'unknown case 99-nope.ts'

printf '%s' '{"format":"adk-eval-run/2","label":"bad","models":[{"id":"m"}],"results":[{"model":"m","case":"01-sql-injection.ts","finding":true}]}' > "$scratch/badformat.json"
reject_check 'an unknown run format' "$scratch/badformat.json" 'format must be adk-eval-run/1'

printf '%s' '{"format":"adk-eval-run/1","label":"bad","models":[{"id":"m"}],"results":[{"model":"m","case":"01-sql-injection.ts","finding":true},{"model":"m","case":"01-sql-injection.ts","finding":true}]}' > "$scratch/dup.json"
reject_check 'a duplicate result' "$scratch/dup.json" 'duplicate result'

# --- 7. --template prints a run skeleton the bench accepts ------------------
node "$BENCH" --template > "$scratch/template.json"
node - "$scratch/template.json" <<'JS'
const run = JSON.parse(require('node:fs').readFileSync(process.argv[2], 'utf8'))
const problems = []
if (run.format !== 'adk-eval-run/1') problems.push(`format is ${run.format}`)
if (run.synthetic !== true) problems.push('the template must be marked synthetic')
if (!run.results.every((r) => r.finding === null)) problems.push('the template must leave finding unfilled')
if (problems.length) { problems.forEach((p) => console.log(`FAIL ${p}`)); process.exit(1) }
console.log('ok --template prints a synthetic run skeleton')
JS
# The skeleton is unfilled by design, so the bench must refuse it.
if node "$BENCH" --runs "$scratch/template.json" --out-dir "$scratch/bad" >/dev/null 2>&1; then
  fail 'the unfilled template was scored'
fi
echo 'ok the unfilled template is refused until a harness fills it'

# --- 8. the markdown report carries the synthetic banner --------------------
node "$BENCH" --runs "$ROOT/evals/calibration/runs/example-synthetic.json" --out-dir "$scratch/md" >/dev/null
grep -q 'SYNTHETIC DATA' "$scratch/md/report.md" || fail 'report.md has no synthetic banner'
grep -q '| Task class | Cases | Cheapest passing model |' "$scratch/md/report.md" || fail 'report.md has no recommendation table'
echo 'ok report.md carries the banner and the recommendation table'

# --- 9. --stdout writes no files -------------------------------------------
node "$BENCH" --runs "$ROOT/evals/calibration/runs/example-synthetic.json" --stdout > "$scratch/stdout.md"
[ ! -f "$scratch/report.md" ] || fail '--stdout wrote report.md'
grep -q 'Calibration report' "$scratch/stdout.md" || fail '--stdout printed no report'
echo 'ok --stdout prints the report without writing files'

# --- 10. validate gates taxonomy drift --------------------------------------
node "$ROOT/scripts/agent-dev-kit.mjs" validate | grep -q 'calibration taxonomy covers all eval cases' \
  || fail 'validate does not check the calibration taxonomy'
echo 'ok validate checks the calibration taxonomy'

printf '\nAll evals calibration contract tests passed.\n'
