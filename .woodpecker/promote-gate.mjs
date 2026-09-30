#!/usr/bin/env node
/**
 * .woodpecker/promote-gate.mjs — the only check a promotion runs.
 *
 * Tests run once per commit, on dev. A promotion (push to staging/main, or a PR
 * into them) carries a commit that already went green, so re-running typecheck/
 * biome/guards/tests there only repeats a result we already have. This step asks
 * GitHub whether an earlier Woodpecker pipeline finished green (Woodpecker posts
 * one commit status per pipeline) for any commit that vouches for this one:
 *   - the commit itself (fast-forward promotion)
 *   - its parents (merge-commit PR merge: the second parent is the green dev tip)
 *   - the head of the PR that produced it (squash / rebase PR merge)
 *
 * A commit nobody vouches for (hotfix straight to main) fails: push it to dev
 * first, or start a manual pipeline on the branch, which runs every gate.
 *
 * Needs: GITHUB_TOKEN (org secret github_token), CI_REPO, CI_COMMIT_SHA, CI_PIPELINE_NUMBER.
 */
const GREEN_CONTEXTS = new Set(["ci/woodpecker/push/ci", "ci/woodpecker/manual/ci", "ci/woodpecker/pr/ci"]);

/** Pure: true when `statuses` holds a green pipeline status for another pipeline than `currentPipeline`. */
export function hasEarlierGreen(statuses, currentPipeline) {
  return statuses.some((status) => {
    if (status.state !== "success" || !GREEN_CONTEXTS.has(status.context)) return false;
    const pipeline = /\/pipeline\/(\d+)/.exec(status.target_url ?? "")?.[1];
    return pipeline !== undefined && pipeline !== String(currentPipeline);
  });
}

async function gh(path) {
  const res = await fetch(`https://api.github.com/repos/${process.env.CI_REPO}/${path}`, {
    headers: { Authorization: `Bearer ${process.env.GITHUB_TOKEN}`, Accept: "application/vnd.github+json" },
  });
  if (!res.ok) {
    console.error(`✗ GitHub ${path} failed (HTTP ${res.status})`);
    process.exit(1);
  }
  return res.json();
}

async function main() {
  const { CI_COMMIT_SHA: sha, CI_PIPELINE_NUMBER: current, CI_COMMIT_BRANCH, CI_COMMIT_TARGET_BRANCH } = process.env;
  const target = CI_COMMIT_BRANCH || CI_COMMIT_TARGET_BRANCH;

  const [commit, pulls] = await Promise.all([gh(`commits/${sha}`), gh(`commits/${sha}/pulls`)]);
  const vouchers = [
    sha,
    ...commit.parents.map((p) => p.sha),
    ...pulls.filter((p) => p.head?.sha && p.head.sha !== sha).map((p) => p.head.sha),
  ];
  for (const candidate of new Set(vouchers)) {
    const statuses = await gh(`commits/${candidate}/statuses?per_page=100`);
    if (hasEarlierGreen(statuses, current)) {
      console.log(
        `✓ ${candidate.slice(0, 7)} already passed CI, promoting ${sha.slice(0, 7)} to ${target} without re-testing`,
      );
      return;
    }
  }
  console.error(`✗ ${sha.slice(0, 7)} has no green pipeline yet (checked itself, parents, PR head).`);
  console.error("  Push it to dev first, or run a manual pipeline on this branch to run every gate.");
  process.exit(1);
}

if (process.argv[1]?.endsWith("promote-gate.mjs")) {
  await main();
}
