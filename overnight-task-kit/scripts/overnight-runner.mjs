#!/usr/bin/env node
import { mkdirSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import process from 'node:process'

function slugify(value) {
  return String(value || 'overnight-task')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 80) || 'overnight-task'
}

function arg(name, fallback = null) {
  const index = process.argv.indexOf(`--${name}`)
  return index === -1 ? fallback : process.argv[index + 1]
}

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '').replace('T', '-').slice(0, 15)
}

function usage() {
  console.log('Usage: overnight-runner.mjs init --title <short-title> [--root <path>]')
}

function write(file, body) {
  writeFileSync(file, `${body.trim()}\n`)
}

function init() {
  const title = arg('title', 'overnight-task')
  const root = resolve(arg('root', process.cwd()))
  const dir = resolve(root, '.agent-runs/overnight', `${timestamp()}-${slugify(title)}`)
  mkdirSync(dir, { recursive: true })

  write(resolve(dir, 'SPEC.md'), `
# SPEC: ${title}

## Objective

Describe the outcome in falsifiable terms.

## In Scope

- [ ] 

## Out of Scope

- [ ] 

## Assumptions

- 

## Risks

- 

## Ambiguity Score

Score: TBD / 1.00

Proceed only when the score is low enough for autonomous execution.
`)

  write(resolve(dir, 'PLAN.md'), `
# PLAN: ${title}

## Tasks

- [ ] T1: 
  - Acceptance:
  - Verification:

## Checkpoints

- [ ] C1 after T1:
`)

  write(resolve(dir, 'JOURNAL.md'), `
# JOURNAL: ${title}

Use UTC or local time consistently.

| Time | Event | Evidence |
| --- | --- | --- |
`)

  write(resolve(dir, 'CHECKPOINTS.md'), `
# CHECKPOINTS: ${title}

At each checkpoint, decide continue / narrow scope / stop and report.

| Checkpoint | Status | Verification | Decision |
| --- | --- | --- | --- |
`)

  write(resolve(dir, 'REPORT.md'), `
# REPORT: ${title}

## Executive Summary

## Files Changed

## Decisions

## Findings

## Verification

## Plan Deviations

## Open Items

## Next Session
`)

  console.log(dir)
}

const command = process.argv[2]
if (command === 'init') init()
else {
  usage()
  process.exit(command ? 1 : 0)
}
