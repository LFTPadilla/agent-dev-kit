#!/usr/bin/env node

const { spawnSync } = require('child_process');
const path = require('path');

const render = path.join(__dirname, 'render.js');
const result = spawnSync(process.execPath, [render, 'E = mc^2'], {
  encoding: 'utf8',
  stdio: ['ignore', 'pipe', 'pipe'],
});

if (result.status !== 0) {
  process.stderr.write(result.stderr || result.stdout || 'tex-render validation failed\n');
  process.exit(result.status || 1);
}

try {
  const payload = JSON.parse(result.stdout.trim().split(/\r?\n/).pop());
  if (!payload.svg || !payload.png) {
    throw new Error('expected svg and png paths');
  }
  process.stdout.write(`tex-render ok: ${payload.png}\n`);
} catch (error) {
  process.stderr.write(`tex-render validation failed: ${error.message}\n`);
  process.stderr.write(result.stdout);
  process.exit(1);
}
