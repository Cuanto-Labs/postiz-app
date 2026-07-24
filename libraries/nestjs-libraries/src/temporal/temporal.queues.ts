/**
 * Task-queue topology.
 *
 * Every workflow itself runs on `main`. Only the social-posting activities are
 * proxied to a per-provider queue, so each provider can carry its own
 * concurrency cap (`maxConcurrentJob` on the provider classes) — which means
 * one Temporal worker per enabled provider.
 *
 * Each worker carries its own workflow bundle, V8 isolate cache and Rust
 * core-bridge. Resident memory is what a container host bills, so on a small
 * install the per-provider split costs more than the concurrency isolation is
 * worth. TEMPORAL_UNIFIED_QUEUE=true collapses everything onto `main`: one
 * worker, one bundle, one cache, one shared concurrency budget.
 *
 * Switching this on is only safe when no post workflow started under the old
 * topology is still running — an in-flight workflow keeps the provider queue
 * it was started with in its arguments, and would stall with no worker there.
 */
export const MAIN_TASK_QUEUE = 'main';

export const isUnifiedQueue = () =>
  process.env.TEMPORAL_UNIFIED_QUEUE === 'true';

/**
 * Activity queue for a provider identifier — `linkedin-page` -> `linkedin`,
 * since sub-providers share their parent's rate limits.
 */
export const activityTaskQueue = (providerIdentifier: string) =>
  isUnifiedQueue()
    ? MAIN_TASK_QUEUE
    : providerIdentifier.split('-')[0].toLowerCase();
