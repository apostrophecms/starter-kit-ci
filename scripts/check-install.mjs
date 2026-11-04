#!/usr/bin/env node
// Fails if npm 12 blocked any dependency install script in a freshly created
// project. npm only warns about blocked scripts and still exits 0, so the
// install itself never catches this.
//
// Usage: check-install.mjs <projectDir> [--expect-npm-pin]
//
// Checks the project root plus backend/ and frontend/ when present (the
// Astro kits install in all three). With --expect-npm-pin, also checks that
// each package.json got the `packageManager: npm@…` pin create-apostrophe
// adds when launched with pnpm.

import { execFileSync } from 'node:child_process';
import { appendFileSync, existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const [ projectDir, ...flags ] = process.argv.slice(2);
if (!projectDir) {
  console.error('Usage: check-install.mjs <projectDir> [--expect-npm-pin]');
  process.exit(2);
}
const expectNpmPin = flags.includes('--expect-npm-pin');

const dirs = [ '.', 'backend', 'frontend' ]
  .map(d => join(projectDir, d))
  .filter(d => existsSync(join(d, 'package.json')));

const problems = [];

for (const dir of dirs) {
  const label = dir === projectDir ? '(root)' : dir.slice(projectDir.length + 1);

  const out = execFileSync('npm', [ 'install-scripts', 'ls', '--json' ], {
    cwd: dir,
    encoding: 'utf8'
  });
  for (const entry of JSON.parse(out).allowScripts ?? []) {
    for (const change of entry.changes ?? []) {
      if (change.change === 'pending') {
        problems.push(`${label}: install script blocked for ${change.key} (add "${entry.name}" to allowScripts, or deny it)`);
      }
    }
  }

  if (expectNpmPin) {
    const pin = JSON.parse(readFileSync(join(dir, 'package.json'), 'utf8')).packageManager;
    if (!/^npm@\d/.test(pin ?? '')) {
      problems.push(`${label}: expected packageManager "npm@…", found ${JSON.stringify(pin)}`);
    }
  }
}

const summary = problems.length
  ? `### Install check failed\n\n${problems.map(p => `- ${p}`).join('\n')}\n`
  : `### Install check passed\n\nChecked: ${dirs.map(d => d === projectDir ? '(root)' : d.slice(projectDir.length + 1)).join(', ')}\n`;

if (process.env.GITHUB_STEP_SUMMARY) {
  appendFileSync(process.env.GITHUB_STEP_SUMMARY, summary);
}
console.log(summary);
process.exit(problems.length ? 1 : 0);
