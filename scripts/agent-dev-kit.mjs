#!/usr/bin/env node
import { spawnSync } from 'node:child_process'
import { existsSync, lstatSync, readdirSync, readFileSync } from 'node:fs'
import { homedir } from 'node:os'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { parseDocument } from 'yaml'

const root = path.resolve(fileURLToPath(new URL('..', import.meta.url)))
const claudePluginFile = path.join(root, 'plugins/dev-skills/.claude-plugin/plugin.json')
const privatePatterns = [
  /(?<![A-Za-z0-9_$}])\/home\/(?!(?:example|user|runner|tutor)\b)[A-Za-z0-9._-]+/i,
  /(?<![A-Za-z0-9_$}])\/Users\/(?!(?:example|user|runner|you)\b)[A-Za-z0-9._-]+/
]
const yamlExtensions = ['.yml', '.yaml']
const profileSkillListKeys = ['include_skills', 'codex_worker_skills']
const tutorCodexSkillsPattern = /PERSONAL_TUTOR_CODEX_SKILLS=\(([^)]*)\)/
const privacyScanExtensions = ['.md', '.json', '.yml', '.yaml', '.mjs', '.js', '.ts', '.tsx', '.sh']
const ignoreDirs = new Set(['.git', '.agents', 'node_modules', '.pi', '.venv', 'venv', 'playwright-report', 'test-results'])

function color(code, text) {
  return process.stdout.isTTY ? `\u001b[${code}m${text}\u001b[0m` : text
}

const ok = (msg) => ({ level: 'ok', msg })
const warn = (msg) => ({ level: 'warn', msg })
const fail = (msg) => ({ level: 'fail', msg })

function checkLabel(level) {
  if (level === 'ok') return color(32, 'OK')
  if (level === 'warn') return color(33, 'WARN')
  return color(31, 'FAIL')
}

function countLevel(checks, level) {
  return checks.filter((check) => check.level === level).length
}

function printChecks(checks) {
  for (const check of checks) console.log(`${checkLabel(check.level)} ${check.msg}`)
  const failures = countLevel(checks, 'fail')
  console.log(`\n${checks.length} checks: ${failures} failed, ${countLevel(checks, 'warn')} warnings`)
  return failures
}

function commandVersion(name) {
  const result = spawnSync(name, ['--version'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })
  if (result.error?.code === 'ENOENT') return null
  if (result.error || result.status !== 0) return 'installed'
  return (result.stdout ?? '').split('\n')[0].trim()
}

function walkFiles(dir, out = []) {
  if (!existsSync(dir)) return out
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (ignoreDirs.has(entry.name)) continue
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) walkFiles(full, out)
    else if (entry.isFile()) out.push(full)
  }
  return out
}

function filesWithExtensions(files, extensions) {
  return files.filter((file) => extensions.some((extension) => file.endsWith(extension)))
}

function hasField(value, field) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return false
  return field in value
}

function missingFields(value, fields) {
  return fields.filter((field) => !hasField(value, field))
}

function stringListOrNull(value) {
  if (!Array.isArray(value) || value.some((item) => typeof item !== 'string')) return null
  return value
}

function unknownNames(names, known) {
  return [...new Set(names)].filter((name) => !known.has(name)).sort()
}

function addMissingFieldFailures(checks, value, fields, label) {
  for (const field of missingFields(value, fields)) checks.push(fail(`${label} missing ${field}`))
}

function readJson(file, checks) {
  try {
    return JSON.parse(readFileSync(file, 'utf8'))
  } catch (error) {
    checks.push(fail(`${rel(file)} is not valid JSON: ${error.message}`))
    return null
  }
}

function readYamlConfig(file) {
  const document = parseDocument(readFileSync(file, 'utf8'), { prettyErrors: true, strict: true })
  return document.errors.length ? null : document.toJS()
}

function rel(file) {
  return path.relative(root, file) || '.'
}

function parseFrontmatter(text) {
  if (!text.startsWith('---\n')) return null
  const end = text.indexOf('\n---', 4)
  if (end === -1) return null
  const raw = text.slice(4, end).trim()
  const fields = new Map()
  for (const line of raw.split('\n')) {
    const match = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/)
    if (match) fields.set(match[1], match[2].trim())
  }
  return fields
}

function skillDirs() {
  const dir = path.join(root, 'plugins/dev-skills/skills')
  if (!existsSync(dir)) return []
  return readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => path.join(dir, entry.name))
    .sort()
}

function bundleDirs(parent) {
  if (!existsSync(parent)) return []
  return readdirSync(parent, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && !ignoreDirs.has(entry.name))
    .filter((entry) => existsSync(path.join(parent, entry.name, 'skills')))
    .map((entry) => entry.name)
}

// A profile may name an individual skill directory, or one of the repo-local
// bundles that runtimes install as a unit (plugins/dev-skills, overnight-task-kit).
function installableSkillNames(dirs) {
  const names = dirs.map((dir) => path.basename(dir))
  const bundles = [root, path.join(root, 'plugins')].flatMap((parent) => bundleDirs(parent))
  return new Set([...names, ...bundles])
}

function validateSkills(checks, { skillDirs: dirs }) {
  if (!dirs.length) {
    checks.push(fail('no skills found under plugins/dev-skills/skills'))
    return
  }
  for (const dir of dirs) {
    const name = path.basename(dir)
    const file = path.join(dir, 'SKILL.md')
    if (!existsSync(file)) {
      checks.push(fail(`${rel(dir)} is missing SKILL.md`))
      continue
    }
    const text = readFileSync(file, 'utf8')
    const fm = parseFrontmatter(text)
    if (!fm) {
      checks.push(fail(`${rel(file)} is missing YAML frontmatter`))
      continue
    }
    const declaredName = fm.get('name')
    const description = fm.get('description')
    if (!declaredName) checks.push(fail(`${rel(file)} is missing frontmatter field: name`))
    else if (declaredName !== name) checks.push(fail(`${rel(file)} name must match directory ${name}`))
    if (!description || description.length < 20) checks.push(fail(`${rel(file)} needs an actionable description`))
  }
  checks.push(ok(`${dirs.length} skill frontmatters checked`))
}

function validateJsonFiles(checks, { files }) {
  for (const file of filesWithExtensions(files, ['.json'])) readJson(file, checks)
  checks.push(ok('JSON files parse'))
}

function validateYamlFiles(checks, { files }) {
  for (const file of filesWithExtensions(files, yamlExtensions)) {
    const text = readFileSync(file, 'utf8')
    if (text.includes('\t')) checks.push(fail(`${rel(file)} contains tabs; use spaces in YAML`))
    if (!text.trim()) checks.push(fail(`${rel(file)} is empty`))
    const document = parseDocument(text, { prettyErrors: true, strict: true })
    for (const error of document.errors) {
      checks.push(fail(`${rel(file)} is not valid YAML: ${error.message.replaceAll('\n', ' ')}`))
    }
  }
  checks.push(ok('YAML files parse with strict syntax checks'))
}

function validatePlugin(checks) {
  const data = readJson(claudePluginFile, checks)
  if (!data) return
  if (!/^\d+\.\d+\.\d+/.test(data.version || '')) checks.push(fail(`${rel(claudePluginFile)} version must be semver-like`))
  if (!data.name || !data.description) checks.push(fail(`${rel(claudePluginFile)} must include name and description`))
  else checks.push(ok('plugin manifest checked'))
}

function validateReleaseVersions(checks) {
  const packageFile = path.join(root, 'package.json')
  const lockFile = path.join(root, 'package-lock.json')
  const codexFile = path.join(root, 'plugins/dev-skills/.codex-plugin/plugin.json')
  const releaseFiles = [packageFile, lockFile, claudePluginFile, codexFile]
  const releaseData = releaseFiles.map((file) => readJson(file, checks))
  if (releaseData.some((data) => !data)) return
  const [packageData, lockData, claudeData, codexData] = releaseData
  const versions = new Map([
    [rel(packageFile), packageData.version],
    [`${rel(lockFile)} root`, lockData.version],
    [`${rel(lockFile)} package`, lockData.packages?.['']?.version],
    [rel(claudePluginFile), claudeData.version],
    [rel(codexFile), codexData.version],
  ])
  const expected = packageData.version
  const mismatches = [...versions].filter(([, version]) => version !== expected)
  for (const [source, version] of mismatches) {
    checks.push(fail(`${source} version ${version ?? 'missing'} does not match ${expected}`))
  }
  if (!mismatches.length) {
    checks.push(ok(`release versions aligned at ${expected}`))
  }
}

function validateProvenance(checks, { skillDirs: dirs }) {
  const file = path.join(root, 'skill-provenance.json')
  const data = readJson(file, checks)
  if (!data) return
  const skills = data.skills || {}
  const actual = dirs.map((dir) => path.basename(dir)).sort()
  const recorded = Object.keys(skills).sort()
  const missing = actual.filter((name) => !recorded.includes(name))
  const stale = recorded.filter((name) => !actual.includes(name))
  for (const name of missing) checks.push(fail(`skill-provenance.json missing skill: ${name}`))
  for (const name of stale) checks.push(fail(`skill-provenance.json has stale skill: ${name}`))
  for (const [name, item] of Object.entries(skills)) {
    addMissingFieldFailures(checks, item, ['source', 'license', 'visibility', 'risk', 'dependencies'], `skill-provenance.json ${name}`)
  }
  if (!missing.length && !stale.length) checks.push(ok('skill provenance covers all skills'))
}

function validateSkillsLock(checks) {
  const file = path.join(root, 'skills-lock.json')
  const data = readJson(file, checks)
  if (!data) return
  const tracked = spawnSync('git', ['ls-files', '--', '.agents'], { cwd: root, encoding: 'utf8' })
  if (tracked.error || tracked.status !== 0) checks.push(warn('git unavailable; skipped the .agents tracking check'))
  else if (tracked.stdout.trim()) checks.push(fail('.agents is tracked in git; third-party skills must stay untracked and be restored from skills-lock.json'))
  const skills = data.skills || {}
  const names = Object.keys(skills)
  if (!names.length) checks.push(fail('skills-lock.json pins no third-party skills'))
  for (const [name, item] of Object.entries(skills)) {
    addMissingFieldFailures(checks, item, ['source', 'skillPath', 'computedHash', 'license'], `skills-lock.json ${name}`)
  }
  checks.push(ok(`${names.length} pinned third-party skills checked`))
}

function validateProfiles(checks, { skillDirs: dirs }) {
  const dir = path.join(root, 'profiles')
  if (!existsSync(dir)) {
    checks.push(fail('profiles/ directory is missing'))
    return
  }
  const files = filesWithExtensions(readdirSync(dir), yamlExtensions)
  if (!files.length) checks.push(fail('profiles/ has no profile manifests'))
  const installable = installableSkillNames(dirs)
  for (const name of files) {
    const file = path.join(dir, name)
    const config = readYamlConfig(file)
    if (!config) continue
    addMissingFieldFailures(checks, config, ['profile', 'runtime', 'sandbox_policy', 'include_skills'], rel(file))
    // A name the kit does not ship is only allowed when this same profile
    // declares it under external_skills; there is no blanket allow.
    const external = stringListOrNull(config.external_skills) ?? []
    const known = new Set([...installable, ...external])
    for (const key of profileSkillListKeys) {
      if (!hasField(config, key)) continue
      const declared = stringListOrNull(config[key])
      if (!declared) {
        checks.push(fail(`${rel(file)} ${key} must be a list of skill names`))
        continue
      }
      for (const unknown of unknownNames(declared, known)) {
        checks.push(fail(`${rel(file)} ${key} names unshipped skill ${unknown}; add it under plugins/dev-skills/skills/ or declare it in external_skills`))
      }
    }
  }
  checks.push(ok(`${files.length} profile manifests checked`))
}

function validateTutorSkillSync(checks) {
  const profileFile = path.join(root, 'profiles/personal-dev-tutor.yml')
  const libFile = path.join(root, 'scripts/personal-tutor-lib.sh')
  for (const file of [profileFile, libFile]) {
    if (!existsSync(file)) {
      checks.push(fail(`${rel(file)} is missing`))
      return
    }
  }
  const declared = stringListOrNull(readYamlConfig(profileFile)?.codex_worker_skills)
  if (!declared) {
    checks.push(fail(`${rel(profileFile)} codex_worker_skills must be a list of skill names`))
    return
  }
  const match = readFileSync(libFile, 'utf8').match(tutorCodexSkillsPattern)
  if (!match) {
    checks.push(fail(`${rel(libFile)} does not define PERSONAL_TUTOR_CODEX_SKILLS`))
    return
  }
  const runtime = match[1].split(/\s+/).filter(Boolean)
  const missingInRuntime = unknownNames(declared, new Set(runtime))
  const extraInRuntime = unknownNames(runtime, new Set(declared))
  for (const name of missingInRuntime) {
    checks.push(fail(`${rel(libFile)} PERSONAL_TUTOR_CODEX_SKILLS is missing ${name} declared in ${rel(profileFile)} codex_worker_skills`))
  }
  for (const name of extraInRuntime) {
    checks.push(fail(`${rel(libFile)} PERSONAL_TUTOR_CODEX_SKILLS has ${name} that ${rel(profileFile)} codex_worker_skills does not declare`))
  }
  if (!missingInRuntime.length && !extraInRuntime.length) {
    checks.push(ok(`tutor Codex allowlist matches ${declared.length} declared worker skills`))
  }
}

function validatePiPackageResearch(checks) {
  const dir = path.join(root, 'pi-profiles')
  const settingsFile = path.join(dir, 'settings.example.json')
  const profilesFile = path.join(dir, 'profiles.yaml')
  const readmeFile = path.join(dir, 'README.md')
  const matrixFile = path.join(dir, 'package-matrix.md')
  const auditFile = path.join(dir, 'context-mode-audit.md')
  const remainingAuditFile = path.join(dir, 'remaining-candidates-audit.md')
  const requiredFiles = [profilesFile, readmeFile, matrixFile, auditFile, remainingAuditFile]

  const settings = readJson(settingsFile, checks)
  if (!settings || !Array.isArray(settings.packages)) {
    checks.push(fail('pi-profiles/settings.example.json must define a packages array'))
  } else if (settings.packages.length !== 0) {
    checks.push(fail('pi-profiles/settings.example.json must remain inert with an empty packages array'))
  }

  const missingFiles = requiredFiles.filter((file) => !existsSync(file))
  for (const file of missingFiles) checks.push(fail(`${rel(file)} is missing`))
  if (missingFiles.length) return

  // The invariant is inertness, and it lives in machine-readable config. Prose in
  // the research docs is deliberately not asserted: rewording a sentence is not a
  // defect, and a gate that reddens for it only teaches people to ignore CI.
  const profilesText = readFileSync(profilesFile, 'utf8')
  const profilesConfig = readYamlConfig(profilesFile)

  if (profilesConfig?.status !== 'research-only' || profilesConfig?.runtime_activation !== 'none') {
    checks.push(fail('pi-profiles/profiles.yaml must remain research-only with no runtime activation'))
  }
  for (const profileName of ['pi-code-review', 'pi-sre-research']) {
    const profile = profilesConfig?.profiles?.[profileName]
    const hasPackageFreeCompatibility = Boolean(profile) &&
      Array.isArray(profile.packages) &&
      profile.packages.length === 0 &&
      profile.runtime_activation === 'metadata-only'
    if (!hasPackageFreeCompatibility) {
      checks.push(fail(`pi-profiles/profiles.yaml must preserve package-free ${profileName} compatibility`))
    }
  }
  if (/(?:npm|git|https?):[^\s"']+/.test(profilesText)) {
    checks.push(fail('pi-profiles/profiles.yaml must not activate or name package sources'))
  }

  checks.push(ok('Pi package research is inert and preserves compatibility contracts'))
}

function validatePolicies(checks) {
  const file = path.join(root, 'policies/sandbox-policies.json')
  const data = readJson(file, checks)
  if (!data) return
  for (const [name, policy] of Object.entries(data.policies || {})) {
    addMissingFieldFailures(checks, policy, ['writes', 'network', 'secrets', 'production', 'git_push', 'destructive_ops'], `sandbox policy ${name}`)
  }
  checks.push(ok('sandbox policies checked'))
}

function validateEvals(checks) {
  const file = path.join(root, 'evals/cases.json')
  const cases = readJson(file, checks)
  if (!Array.isArray(cases)) return
  const seen = new Set()
  let planted = 0
  for (const c of cases) {
    if (!c.file || typeof c.plantedBug !== 'boolean') checks.push(fail(`invalid eval case entry: ${JSON.stringify(c)}`))
    if (seen.has(c.file)) checks.push(fail(`duplicate eval case: ${c.file}`))
    seen.add(c.file)
    if (c.file && !existsSync(path.join(root, 'evals/cases', c.file))) checks.push(fail(`eval case file missing: ${c.file}`))
    if (c.plantedBug) planted++
  }
  const controls = cases.length - planted
  if (cases.length < 12) checks.push(fail('eval suite should have at least 12 cases'))
  if (controls < 2) checks.push(fail('eval suite should have at least 2 clean controls'))
  checks.push(ok(`eval suite checked (${planted} planted, ${controls} controls)`))
}

function validateLinks(checks, { files }) {
  const markdown = filesWithExtensions(files, ['.md'])
  const linkPattern = /\[[^\]]+\]\(([^)]+)\)/g
  for (const file of markdown) {
    const text = readFileSync(file, 'utf8')
    for (const match of text.matchAll(linkPattern)) {
      const target = match[1]
      if (/^(https?:|mailto:|#)/.test(target)) continue
      const clean = target.split('#')[0]
      if (!clean || clean.includes('<') || clean.includes('>')) continue
      const resolved = path.resolve(path.dirname(file), clean)
      if (!existsSync(resolved)) checks.push(fail(`${rel(file)} links to missing ${target}`))
    }
  }
  checks.push(ok('relative markdown links checked'))
}

function privacyScan(checks, { files }) {
  const offenders = []
  for (const file of filesWithExtensions(files, privacyScanExtensions)) {
    if (file.includes('plugins/dev-skills/skills/drawio-skill/data/lobe-icons.json')) continue
    const text = readFileSync(file, 'utf8')
    const pattern = privatePatterns.find((candidate) => candidate.test(text))
    if (pattern) offenders.push(`${rel(file)} matches ${pattern}`)
  }
  if (offenders.length) offenders.forEach((item) => checks.push(fail(`private coupling: ${item}`)))
  else checks.push(ok('privacy scan found no private project coupling'))
}

function collectValidationChecks() {
  const checks = []
  const validationContext = {
    files: walkFiles(root),
    skillDirs: skillDirs()
  }
  for (const validator of [
    validateJsonFiles,
    validateYamlFiles,
    validatePlugin,
    validateReleaseVersions,
    validateSkills,
    validateProvenance,
    validateSkillsLock,
    validateProfiles,
    validateTutorSkillSync,
    validatePiPackageResearch,
    validatePolicies,
    validateEvals,
    validateLinks,
    privacyScan
  ]) validator(checks, validationContext)
  return checks
}

function validate() {
  return printChecks(collectValidationChecks())
}

function runtimeTargets() {
  return [
    ['Claude', path.join(homedir(), '.claude/skills')],
    ['Claude secondary', path.join(homedir(), '.claude-very/skills')],
    ['Codex', path.join(homedir(), '.agents/skills')],
    ['Pi', path.join(homedir(), '.pi/agent/skills')],
    ['OpenCode commands', path.join(homedir(), '.config/opencode/command')]
  ]
}

function doctor() {
  const checks = []
  for (const name of ['node', 'npm', 'git', 'rg', 'hypa', 'claude', 'pi', 'opencode', 'semgrep']) {
    const version = commandVersion(name)
    checks.push(version ? ok(`${name}: ${version}`) : warn(`${name}: not found`))
  }
  for (const [label, target] of runtimeTargets()) {
    if (!existsSync(target)) {
      checks.push(warn(`${label} skills target missing: ${target}`))
      continue
    }
    const entries = readdirSync(target)
    const broken = entries.filter((entry) => {
      const full = path.join(target, entry)
      return lstatSync(full).isSymbolicLink() && !existsSync(full)
    })
    checks.push(broken.length ? fail(`${label} has broken skill symlinks: ${broken.join(', ')}`) : ok(`${label} target ready: ${target}`))
  }
  // Collect without printing, so doctor prints one summary instead of two. The
  // warning level is carried through so a validate warning stays visible here
  // without turning into a doctor failure.
  const validationChecks = collectValidationChecks()
  const validationFailures = countLevel(validationChecks, 'fail')
  const validationWarnings = countLevel(validationChecks, 'warn')
  const detail = 'run `agent-dev-kit validate` for detail'
  if (validationFailures) checks.push(fail(`validate has ${validationFailures} failures; ${detail}`))
  else if (validationWarnings) checks.push(warn(`validate passed with ${validationWarnings} warnings; ${detail}`))
  else checks.push(ok('validate passed'))
  return printChecks(checks)
}

function inventory() {
  const provenance = readJson(path.join(root, 'skill-provenance.json'), [])
  const dirs = skillDirs()
  console.log(`# agent-dev-kit inventory\n`)
  console.log(`Root: ${root}`)
  console.log(`Skills: ${dirs.length}`)
  for (const dir of dirs) {
    const name = path.basename(dir)
    const item = provenance?.skills?.[name]
    console.log(`- ${name}${item ? ` (${item.risk}, ${item.visibility})` : ''}`)
  }
  console.log(`\nRuntimes:`)
  for (const [label, target] of runtimeTargets()) {
    console.log(`- ${label}: ${existsSync(target) ? target : 'missing'}`)
  }
}

function usage() {
  console.log(`Usage: agent-dev-kit <doctor|validate|inventory>`)
}

const command = process.argv[2]
if (command === 'doctor') process.exit(doctor() ? 1 : 0)
else if (command === 'validate') process.exit(validate() ? 1 : 0)
else if (command === 'inventory') inventory()
else {
  usage()
  process.exit(command ? 1 : 0)
}
