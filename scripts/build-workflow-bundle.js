/**
 * Pre-bundles the Temporal workflow code at build time.
 *
 * Without this, every worker webpacks the workflow tree itself on boot: N
 * bundler runs, an N-fold startup memory spike, and N resident copies. With
 * the artifact present, `temporal.module.ts` hands each worker the same
 * `workflowBundle.codePath` instead.
 *
 * Non-fatal by design — on failure the workers fall back to `workflowsPath`
 * and bundle at runtime as before, so a bundler problem degrades the memory
 * profile rather than breaking the deploy.
 */
const { writeFileSync, existsSync, mkdirSync } = require('node:fs');
const { resolve, dirname } = require('node:path');

const OUTPUT = resolve(
  __dirname,
  '../apps/orchestrator/dist/workflow-bundle.js'
);

// The orchestrator's own build is the normal source. The backend build emits a
// copy of the same tree (it pulls the workflows in through the path alias), so
// it works as a fallback when only the backend was built.
const CANDIDATES = [
  resolve(
    __dirname,
    '../apps/orchestrator/dist/apps/orchestrator/src/workflows'
  ),
  resolve(__dirname, '../apps/backend/dist/apps/orchestrator/src/workflows'),
];

async function main() {
  const workflowsPath = CANDIDATES.find((candidate) =>
    existsSync(`${candidate}/index.js`)
  );

  if (!workflowsPath) {
    console.warn(
      '[build-workflow-bundle] no compiled workflows found — skipping, workers will bundle at runtime'
    );
    return;
  }

  const { bundleWorkflowCode } = require('@temporalio/worker');
  const { code } = await bundleWorkflowCode({ workflowsPath });

  mkdirSync(dirname(OUTPUT), { recursive: true });
  writeFileSync(OUTPUT, code);

  console.log(
    `[build-workflow-bundle] wrote ${OUTPUT} (${(
      code.length /
      1024 /
      1024
    ).toFixed(2)} MiB)`
  );
}

main().catch((err) => {
  console.warn(
    '[build-workflow-bundle] failed, workers will bundle at runtime:',
    err?.message || err
  );
});
