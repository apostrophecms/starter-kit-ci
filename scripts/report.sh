#!/usr/bin/env bash
# Turns the install matrix result into alerts, only on a change of state:
#
#   failure, no open issue  -> open the tracking issue, post to Slack
#   failure, issue open     -> comment on the issue (no Slack)
#   success, issue open     -> comment, close the issue, post "recovered"
#   success, no open issue  -> nothing
#
# Env: RESULT (success|failure), GH_TOKEN, GITHUB_* from Actions,
#      SLACK_WEBHOOK_URL (optional; Slack is skipped when unset).
set -euo pipefail

LABEL=install-failure
RUN_URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"

slack() {
  if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
    echo "SLACK_WEBHOOK_URL not set; skipping Slack."
    return
  fi
  jq -n --arg text "$1" '{text: $text}' |
    curl -fsS -X POST -H 'Content-Type: application/json' --data @- "$SLACK_WEBHOOK_URL"
}

gh label create "$LABEL" --repo "$GITHUB_REPOSITORY" --color B60205 \
  --description 'Scheduled starter kit install test is failing' 2>/dev/null || true

issue=$(gh issue list --repo "$GITHUB_REPOSITORY" --label "$LABEL" --state open \
  --json number --jq '.[0].number // empty')

if [ "$RESULT" = failure ]; then
  failed=$(gh run view "$GITHUB_RUN_ID" --repo "$GITHUB_REPOSITORY" --json jobs \
    --jq '.jobs[] | select(.conclusion == "failure") | "- \(.name)"')
  body=$(printf 'Run: %s\n\nFailed jobs:\n%s\n' "$RUN_URL" "$failed")

  if [ -n "$issue" ]; then
    gh issue comment "$issue" --repo "$GITHUB_REPOSITORY" --body "Still failing. $body"
  else
    url=$(gh issue create --repo "$GITHUB_REPOSITORY" --label "$LABEL" \
      --title 'Starter kit install test is failing' \
      --body "$(printf '%s\n\nNew users installing these kits with create-apostrophe are likely hitting this too. This issue closes automatically when a scheduled run passes.\n' "$body")")
    slack "$(printf ':rotating_light: Starter kit install test is failing.\n%s\nTracking issue: %s' "$failed" "$url")"
  fi
else
  if [ -n "$issue" ]; then
    gh issue comment "$issue" --repo "$GITHUB_REPOSITORY" --body "Passing again: $RUN_URL"
    gh issue close "$issue" --repo "$GITHUB_REPOSITORY"
    slack "$(printf ':white_check_mark: Starter kit install test recovered.\n%s' "$RUN_URL")"
  else
    echo "Passing, no open issue. Nothing to report."
  fi
fi
