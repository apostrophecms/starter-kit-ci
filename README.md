# starter-kit-ci

Daily install test for the ApostropheCMS starter kits that
[`create-apostrophe`](https://github.com/apostrophecms/apostrophe/tree/main/packages/create-apostrophe)
offers:

- [starter-kit-essentials](https://github.com/apostrophecms/starter-kit-essentials)
- [public-demo](https://github.com/apostrophecms/public-demo)
- [starter-kit-astro-essentials](https://github.com/apostrophecms/starter-kit-astro-essentials)
- [astro-public-demo](https://github.com/apostrophecms/astro-public-demo)

This lives in its own repo so the workflow doesn't get copied into every
project people start from a kit.

## What it does

For each kit, launched with both `npm create apostrophe` (npm 12) and
`pnpm create apostrophe`, the workflow:

1. Runs the published installer unattended, which clones the kit's current
   default branch and installs dependencies fresh (the kits ship without
   lockfiles).
2. Fails if npm blocked any dependency install script that isn't covered by
   the kit's `allowScripts`. npm 12 only warns about these and still exits 0.
   For pnpm launches, it also checks that each `package.json` was pinned to
   `packageManager: npm@…`.
3. Runs `npm run build`.

## Alerts

Alerts go out only when the status changes:

- The first failure opens an issue labelled `install-failure` and posts to
  Slack (`#product-releases`).
- Further failures only add a comment to that issue.
- The first passing run closes the issue and posts "recovered".

Slack needs the `SLACK_WEBHOOK_URL` repository secret (an incoming webhook
for the channel). Without it, issues still work and the Slack post is skipped.

## When it fails

Open the failed job. The "Check for blocked install scripts" step summary
names the package. Then in the kit repo, either add it to `allowScripts` in
the right `package.json`, if the script is needed, or deny it with
`npm install-scripts deny <pkg>`.

## Running it by hand

Actions → Starter kit installs → Run workflow. By default a manual run
doesn't touch the issue or Slack. Tick **notify** to have it behave like a
scheduled run.

## Keeping in sync

The kit list in the workflow matrix mirrors `KITS` in
`packages/create-apostrophe/src/core/kits.js`. Update both when a kit is
added or removed.
