#!/bin/sh
# Called by the `vercel-deploy` CI step once every gate is green. Asks Vercel to build and
# deploy this exact commit through its GitHub integration.
#
# Why: Vercel's own git-push builds are OFF for this project (vercel.json
# `git.deploymentEnabled: false`, 2026-09-23). Before that, Vercel built every
# push in parallel with CI and never looked at the CI result, so red code shipped as failed
# deploys (~110 in 30 days). The build still runs on Vercel, so env vars (including
# `sensitive` ones), Neon preview-branch provisioning and Payload migrations behave exactly as
# before; only the trigger moved. API deploys are made by the token owner, so the
# commit-author seat gate (COMMIT_AUTHOR_REQUIRED) no longer applies.
#
# Needs: VERCEL_TOKEN (org secret vercel_token), VERCEL_PROJECT.
set -eu
TEAM=team_DNaIj8z7CcumC12wSpDZmQzH

if [ "$CI_PIPELINE_EVENT" = pull_request ]; then
  REF="$CI_COMMIT_SOURCE_BRANCH"
  # dev/staging/main already deploy on their own push; a promotion PR would only duplicate it.
  case "$REF" in dev|staging|main) echo "PR from $REF: already deployed by its push pipeline, skipping"; exit 0 ;; esac
else
  REF="$CI_COMMIT_BRANCH"
fi

TARGET=""
if [ "$CI_PIPELINE_EVENT" = push ] && [ "$REF" = main ]; then TARGET=',"target":"production"'; fi

body=$(printf '{"name":"%s","project":"%s"%s,"gitSource":{"type":"github","repoId":%s,"ref":"%s","sha":"%s"}}' \
  "$VERCEL_PROJECT" "$VERCEL_PROJECT" "$TARGET" "$CI_REPO_REMOTE_ID" "$REF" "$CI_COMMIT_SHA")

resp=$(curl -sS -X POST "https://api.vercel.com/v13/deployments?teamId=$TEAM" \
  -H "Authorization: Bearer $VERCEL_TOKEN" -H "Content-Type: application/json" -d "$body")

id=$(printf '%s' "$resp" | grep -o '"id":"dpl_[A-Za-z0-9]*"' | head -1 | cut -d'"' -f4)
if [ -z "$id" ]; then
  echo "Vercel refused the deploy request:"
  printf '%s\n' "$resp" | head -c 600
  exit 1
fi
url=$(printf '%s' "$resp" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "Vercel deployment $id queued for $REF@$CI_COMMIT_SHA ${TARGET:+(production)}"
echo "https://$url  |  https://vercel.com/cuantolabs/$VERCEL_PROJECT/$(echo "$id" | sed 's/^dpl_//')"
