// Calibration bench for the evals/ case set.
//
// Question this answers: for each task class, which is the cheapest model that
// still gets the case right?
//
// This runner NEVER calls a model. It reads run files that some harness wrote,
// and it joins them with the taxonomy in taxonomy.json. Any harness can produce
// a run file: the format is documented in README.md.
//
// Usage:
//   node evals/calibration/run.mjs                        # read runs/*.json
//   node evals/calibration/run.mjs --runs a.json b.json   # read named runs
//   node evals/calibration/run.mjs --runs-dir elsewhere   # read another runs folder
//   node evals/calibration/run.mjs --template             # print an empty run
//   node evals/calibration/run.mjs --min-pass 0.9         # relax the pass bar
//   node evals/calibration/run.mjs --stdout               # print the report only
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const casesFile = path.join(here, '..', 'cases.json')
const taxonomyFile = path.join(here, 'taxonomy.json')
const defaultRunsDir = path.join(here, 'runs')

const RUN_FORMAT = 'adk-eval-run/1'

function parseArgs(argv) {
  const options = { runs: [], runsDir: defaultRunsDir, outDir: here, minPass: 1, template: false, stdout: false }
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i]
    if (arg === '--runs') options.runs.push(argv[++i])
    else if (arg === '--runs-dir') options.runsDir = argv[++i]
    else if (arg === '--out-dir') options.outDir = argv[++i]
    else if (arg === '--min-pass') options.minPass = Number(argv[++i])
    else if (arg === '--template') options.template = true
    else if (arg === '--stdout') options.stdout = true
    else if (arg === '-h' || arg === '--help') options.help = true
    else fail(`unknown argument: ${arg}`)
  }
  if (!Number.isFinite(options.minPass) || options.minPass < 0 || options.minPass > 1) {
    fail('--min-pass must be a number from 0 to 1')
  }
  return options
}

function fail(message) {
  console.error(`calibration: ${message}`)
  process.exit(2)
}

function readJson(file) {
  try {
    return JSON.parse(readFileSync(file, 'utf8'))
  } catch (error) {
    fail(`cannot read ${file}: ${error.message}`)
  }
}

// A case passes when the model agreed with the case intent: report a finding on
// a planted bug, stay silent on a clean control.
function casePasses(evalCase, finding) {
  return evalCase.plantedBug ? finding : !finding
}

function resultCostUsd(model, result) {
  if (typeof result.cost_usd === 'number') return result.cost_usd
  const priced = typeof model.price_in_per_mtok === 'number' || typeof model.price_out_per_mtok === 'number'
  if (!priced) return null
  const tokensIn = typeof result.tokens_in === 'number' ? result.tokens_in : null
  const tokensOut = typeof result.tokens_out === 'number' ? result.tokens_out : null
  if (tokensIn === null && tokensOut === null) return null
  const priceIn = model.price_in_per_mtok ?? 0
  const priceOut = model.price_out_per_mtok ?? 0
  return ((tokensIn ?? 0) * priceIn + (tokensOut ?? 0) * priceOut) / 1e6
}

function loadRuns(options) {
  let files = options.runs
  if (!files.length) {
    if (!existsSyncDir(options.runsDir)) return []
    files = readdirSync(options.runsDir)
      .filter((name) => name.endsWith('.json'))
      .sort()
      .map((name) => path.join(options.runsDir, name))
  }
  return files.map((file) => {
    const run = readJson(file)
    run.file = file
    return run
  })
}

function existsSyncDir(dir) {
  try {
    readdirSync(dir)
    return true
  } catch {
    return false
  }
}

function validateRun(run, caseByFile) {
  const errors = []
  const label = run.label || run.file
  if (run.format !== RUN_FORMAT) errors.push(`${label}: format must be ${RUN_FORMAT}`)
  if (typeof run.label !== 'string' || !run.label) errors.push(`${label}: label is required`)
  if (!Array.isArray(run.models) || !run.models.length) errors.push(`${label}: models must be a non-empty array`)
  if (!Array.isArray(run.results) || !run.results.length) errors.push(`${label}: results must be a non-empty array`)
  const modelIds = new Set((run.models || []).map((model) => model.id))
  for (const model of run.models || []) {
    if (typeof model.id !== 'string' || !model.id) errors.push(`${label}: every model needs a string id`)
    if (model.price_in_per_mtok !== undefined && typeof model.price_in_per_mtok !== 'number') {
      errors.push(`${label}: ${model.id}: price_in_per_mtok must be a number`)
    }
    if (model.price_out_per_mtok !== undefined && typeof model.price_out_per_mtok !== 'number') {
      errors.push(`${label}: ${model.id}: price_out_per_mtok must be a number`)
    }
  }
  const seen = new Set()
  for (const result of run.results || []) {
    const key = `${result.model}::${result.case}`
    if (!modelIds.has(result.model)) errors.push(`${label}: result names undeclared model ${result.model}`)
    if (!caseByFile.has(result.case)) errors.push(`${label}: result names unknown case ${result.case}`)
    if (seen.has(key)) errors.push(`${label}: duplicate result for ${key}`)
    seen.add(key)
    if (typeof result.finding !== 'boolean') {
      errors.push(`${label}: ${key}: finding must be true or false (unfilled template?)`)
    }
  }
  return errors
}

function template(cases, taxonomy) {
  const results = []
  for (const evalCase of cases) {
    for (const model of ['example/model-a', 'example/model-b']) {
      results.push({
        model,
        case: evalCase.file,
        finding: null,
        notes: 'set finding to true when the model reported a finding on this file'
      })
    }
  }
  return {
    format: RUN_FORMAT,
    label: 'replace-me',
    synthetic: true,
    source: 'describe the harness that produced this run',
    created: new Date().toISOString().slice(0, 10),
    models: [
      { id: 'example/model-a', price_in_per_mtok: 0.1, price_out_per_mtok: 0.4 },
      { id: 'example/model-b', price_in_per_mtok: 1, price_out_per_mtok: 4 }
    ],
    results,
    classes: Object.keys(taxonomy.classes)
  }
}

function buildReport(cases, taxonomy, runs, options) {
  const caseByFile = new Map(cases.map((evalCase) => [evalCase.file, evalCase]))
  const classOf = new Map(Object.entries(taxonomy.cases).map(([file, entry]) => [file, entry.class]))
  const classCaseCount = new Map()
  for (const evalCase of cases) {
    const name = classOf.get(evalCase.file)
    classCaseCount.set(name, (classCaseCount.get(name) || 0) + 1)
  }

  // model -> class -> tally
  const models = new Map()
  const errors = []
  for (const run of runs) {
    errors.push(...validateRun(run, caseByFile))
  }
  if (errors.length) {
    for (const error of errors) console.error(`calibration: ${error}`)
    process.exit(2)
  }

  for (const run of runs) {
    for (const model of run.models) {
      if (!models.has(model.id)) {
        models.set(model.id, {
          id: model.id,
          run: run.label,
          synthetic: run.synthetic === true,
          price_in_per_mtok: model.price_in_per_mtok ?? null,
          price_out_per_mtok: model.price_out_per_mtok ?? null,
          classes: new Map(),
          costSum: 0,
          costCount: 0
        })
      }
      const entry = models.get(model.id)
      if (model.price_in_per_mtok !== undefined) entry.price_in_per_mtok = model.price_in_per_mtok
      if (model.price_out_per_mtok !== undefined) entry.price_out_per_mtok = model.price_out_per_mtok
    }
    for (const result of run.results) {
      const evalCase = caseByFile.get(result.case)
      const name = classOf.get(result.case)
      const entry = models.get(result.model)
      const tally = entry.classes.get(name) || { attempted: 0, passed: 0, costSum: 0, costCount: 0 }
      tally.attempted += 1
      if (casePasses(evalCase, result.finding)) tally.passed += 1
      const cost = resultCostUsd(entry, result)
      if (cost !== null) {
        tally.costSum += cost
        tally.costCount += 1
        entry.costSum += cost
        entry.costCount += 1
      }
      entry.classes.set(name, tally)
    }
  }

  const modelList = [...models.values()].map((entry) => ({
    ...entry,
    meanCostPerCase: entry.costCount ? entry.costSum / entry.costCount : null
  }))

  const classes = Object.entries(taxonomy.classes).map(([name, meta]) => {
    const total = classCaseCount.get(name) || 0
    const candidates = modelList
      .map((model) => {
        const tally = model.classes.get(name) || { attempted: 0, passed: 0, costSum: 0, costCount: 0 }
        return {
          model: model.id,
          attempted: tally.attempted,
          passed: tally.passed,
          passRate: tally.attempted ? tally.passed / tally.attempted : null,
          complete: tally.attempted === total,
          meanCostPerCase: tally.costCount ? tally.costSum / tally.costCount : null
        }
      })
      .filter((row) => row.attempted > 0)
    const passing = candidates.filter((row) => row.passRate !== null && row.passRate >= options.minPass)
    const complete = passing.filter((row) => row.complete)
    const pool = complete.length ? complete : passing
    const priced = pool.filter((row) => row.meanCostPerCase !== null)
    // Cheapest first. A complete pool is ranked on cost; a partial pool has no
    // comparable cost, so it is ranked by name and the report says "partial".
    const ranking = priced.length
      ? [...priced].sort((a, b) => a.meanCostPerCase - b.meanCostPerCase || a.model.localeCompare(b.model))
      : [...pool].sort((a, b) => a.model.localeCompare(b.model))
    const pick = ranking[0] || null
    const confidence = !pick ? 'none' : complete.length ? (priced.length ? 'priced' : 'cost-unknown') : 'partial'
    return {
      class: name,
      description: meta.description,
      cases: total,
      recommendation: pick ? pick.model : null,
      recommendationCostPerCase: confidence === 'priced' ? pick.meanCostPerCase : null,
      confidence,
      candidates
    }
  })

  return {
    format: 'adk-eval-calibration/1',
    minPass: options.minPass,
    synthetic: modelList.some((model) => model.synthetic),
    runs: runs.map((run) => ({
      label: run.label,
      file: path.relative(path.join(here, '..', '..'), run.file),
      synthetic: run.synthetic === true,
      source: run.source || null
    })),
    models: modelList.map((model) => ({
      id: model.id,
      synthetic: model.synthetic,
      price_in_per_mtok: model.price_in_per_mtok,
      price_out_per_mtok: model.price_out_per_mtok,
      meanCostPerCase: model.meanCostPerCase
    })),
    classes,
    warnings: buildWarnings(modelList, classes, runs)
  }
}

function buildWarnings(modelList, classes, runs) {
  const warnings = []
  if (modelList.some((model) => model.synthetic)) {
    warnings.push('SYNTHETIC DATA: at least one run is synthetic; these are not real model results.')
  }
  if (!runs.length) warnings.push('No run files found. The report is empty by design.')
  for (const row of classes) {
    if (!row.recommendation) {
      warnings.push(`Class ${row.class}: no model passed the class at the pass bar. Do not route this class by cost yet.`)
    } else if (row.confidence === 'cost-unknown') {
      warnings.push(`Class ${row.class}: no run records cost. The pick is the first passing model, not the cheapest.`)
    } else if (row.confidence === 'partial') {
      warnings.push(`Class ${row.class}: no model attempted every case. The pick is a partial result, not a verdict.`)
    }
  }
  return warnings
}

function renderMarkdown(report, taxonomy) {
  const lines = []
  lines.push('# Calibration report: task class to cheapest passing model')
  lines.push('')
  if (report.synthetic) {
    lines.push('> **SYNTHETIC DATA.** At least one input run is marked synthetic. The numbers below')
    lines.push('> come from made-up results, not from real model runs. Use this report to check the')
    lines.push('> method, not to pick a model.')
    lines.push('')
  }
  lines.push(`Pass bar: a model must pass every case of the class (pass rate >= ${report.minPass}).`)
  lines.push('')
  lines.push('## Recommendation')
  lines.push('')
  lines.push('| Task class | Cases | Cheapest passing model | Mean cost per case (USD) | Confidence |')
  lines.push('|---|---|---|---|---|')
  for (const row of report.classes) {
    const cost = row.recommendationCostPerCase === null ? 'n/a' : row.recommendationCostPerCase.toFixed(6)
    lines.push(`| ${row.class} | ${row.cases} | ${row.recommendation ?? 'none'} | ${cost} | ${row.confidence} |`)
  }
  lines.push('')
  lines.push('## Pass rate by model and class')
  lines.push('')
  const header = report.classes.map((row) => row.class)
  lines.push(`| Model | ${header.join(' | ')} |`)
  lines.push(`|---|${header.map(() => '---').join('|')}|`)
  for (const model of report.models) {
    const cells = report.classes.map((row) => {
      const candidate = row.candidates.find((item) => item.model === model.id)
      if (!candidate) return '-'
      const rate = candidate.passRate === null ? 'n/a' : `${Math.round(candidate.passRate * 100)}%`
      return candidate.complete ? rate : `${rate} (${candidate.attempted}/${row.cases})`
    })
    lines.push(`| ${model.id} | ${cells.join(' | ')} |`)
  }
  lines.push('')
  lines.push('## Classes')
  lines.push('')
  for (const row of report.classes) {
    lines.push(`1. **${row.class}** (${row.cases} cases): ${row.description}`)
  }
  lines.push('')
  lines.push('## Runs read')
  lines.push('')
  for (const run of report.runs) {
    lines.push(`1. ${run.label} (${run.file})${run.synthetic ? ' [synthetic]' : ''}${run.source ? `: ${run.source}` : ''}`)
  }
  lines.push('')
  lines.push('## Warnings')
  lines.push('')
  if (!report.warnings.length) lines.push('None.')
  for (const warning of report.warnings) lines.push(`1. ${warning}`)
  lines.push('')
  lines.push('## How to read this')
  lines.push('')
  lines.push('1. A class with no recommendation has no model that passed the class. Fix the class')
  lines.push('   prompt or keep the strong model there.')
  lines.push('2. 15 cases is a smoke test. Treat a single miss as a signal, not a verdict.')
  lines.push('3. A confidence of partial means no model attempted the whole class. Read the pass')
  lines.push('   matrix before you route on it.')
  lines.push('4. Cost is per case of that class as recorded by the run file. It excludes retries')
  lines.push('   and review time.')
  lines.push('')
  return lines.join('\n')
}

function main() {
  const options = parseArgs(process.argv.slice(2))
  const cases = readJson(casesFile)
  const taxonomy = readJson(taxonomyFile)

  if (options.help) {
    console.log(readFileSync(fileURLToPath(import.meta.url), 'utf8').split('\n').slice(0, 14).join('\n'))
    return
  }
  if (options.template) {
    console.log(JSON.stringify(template(cases, taxonomy), null, 2))
    return
  }

  const runs = loadRuns(options)
  const report = buildReport(cases, taxonomy, runs, options)
  const markdown = renderMarkdown(report, taxonomy)

  if (options.stdout) {
    console.log(markdown)
    return
  }
  mkdirSync(options.outDir, { recursive: true })
  writeFileSync(path.join(options.outDir, 'report.json'), `${JSON.stringify(report, null, 2)}\n`)
  writeFileSync(path.join(options.outDir, 'report.md'), markdown)
  console.log(`calibration: read ${runs.length} run(s), wrote report.json and report.md`)
  for (const row of report.classes) {
    console.log(`  ${row.class}: ${row.recommendation ?? 'none'} (${row.confidence})`)
  }
  for (const warning of report.warnings) console.log(`  WARN ${warning}`)
}

main()
