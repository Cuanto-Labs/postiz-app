#!/usr/bin/env node
/**
 * .woodpecker/promote-gate.mjs — the only check a staging/main push runs.
 *
 * Tests run once per commit, on dev. A promotion pushes that same sha to
 * staging/main, so re-running typecheck/biome/guards/tests there only repeats
 * a result we already have. This step instead asks GitHub whether an earlier
 * Woodpecker pipeline for this exact sha finished green (Woodpecker posts one
 * commit status per pipeline) and fails the promotion if none did.
 *
 * A sha that never went through dev (hotfix) is not promotable by push: push it
 * to dev first, or start a manual pipeline on the branch, which runs every gate.
 *
 * Needs: GITHUB_TOKEN (org secret github_token), CI_REPO, CI_COMMIT_SHA, CI_PIPELINE_NUMBER.
 */
const GREEN_CONTEXTS = new Set(["ci/woodpecker/push/ci", "ci/woodpecker/manual/ci"]);

/** Pure: true when `statuses` holds a green pipeline status for another pipeline than `currentPipeline`. */
export function hasEarlierGreen(statuses, currentPipeline) {
  return statuses.some((status) => {
    if (status.state !== "success" || !GREEN_CONTEXTS.has(status.context)) return false;
    const pipeline = /\/pipeline\/(\d+)/.exec(status.target_url ?? "")?.[1];
    return pipeline !== undefined && pipeline !== String(currentPipeline);
  });
}

async function main() {
  const { GITHUB_TOKEN, CI_REPO, CI_COMMIT_SHA, CI_PIPELINE_NUMBER, CI_COMMIT_BRANCH } = process.env;
  const res = await fetch(`https://api.github.com/repos/${CI_REPO}/commits/${CI_COMMIT_SHA}/statuses?per_page=100`, {
    headers: { Authorization: `Bearer ${GITHUB_TOKEN}`, Accept: "application/vnd.github+json" },
  });
  if (!res.ok) {
    console.error(`✗ could not read commit statuses (HTTP ${res.status})`);
    process.exit(1);
  }
  if (hasEarlierGreen(await res.json(), CI_PIPELINE_NUMBER)) {
    console.log(
      `✓ ${CI_COMMIT_SHA.slice(0, 7)} already passed CI, promoting to ${CI_COMMIT_BRANCH} without re-testing`,
    );
    return;
  }
  console.error(`✗ ${CI_COMMIT_SHA.slice(0, 7)} has no green pipeline yet.`);
  console.error("  Push it to dev first, or run a manual pipeline on this branch to run every gate.");
  process.exit(1);
}

if (process.argv[1]?.endsWith("promote-gate.mjs")) {
  await main();
}
