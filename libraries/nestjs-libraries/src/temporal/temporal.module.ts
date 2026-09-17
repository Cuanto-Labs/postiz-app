import { TemporalModule } from 'nestjs-temporal-core';
import { socialIntegrationList } from '@gitroom/nestjs-libraries/integrations/integration.manager';
import {
  MAIN_TASK_QUEUE,
  isUnifiedQueue,
} from '@gitroom/nestjs-libraries/temporal/temporal.queues';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

// The SDK derives the default workflow cache size from the V8 heap ceiling, so
// a container with a large --max-old-space-size reserves far more than a
// single-tenant install ever uses. Cache size is resident memory.
const workerMemoryOptions = {
  maxCachedWorkflows: Number(process.env.TEMPORAL_MAX_CACHED_WORKFLOWS) || 10,
  reuseV8Context: true,
};

/**
 * Prefer the bundle produced by `pnpm run build:workflows`. Passing
 * `workflowsPath` instead makes every worker run webpack at boot — a startup
 * memory spike plus a per-worker resident cost. Falls back to bundling on the
 * fly when the artifact is missing (dev, or a build that skipped the step).
 */
const workflowSource = (workflowsPath?: string) => {
  const bundle = [
    process.env.TEMPORAL_WORKFLOW_BUNDLE,
    resolve(process.cwd(), 'apps/orchestrator/dist/workflow-bundle.js'),
  ]
    .filter((candidate): candidate is string => !!candidate)
    .find((candidate) => existsSync(candidate));

  return bundle ? { workflowBundle: { codePath: bundle } } : { workflowsPath };
};

export const getTemporalModule = (
  isWorkers: boolean,
  path?: string,
  activityClasses?: any[]
) => {
  // Queues this worker server should NOT run, comma-separated
  // (e.g. EXCLUDE_QUEUE="reddit,x,twitch"). Use it to pin a queue to a single
  // server: exclude it on every server except the one that should own it.
  // Meant for the providers whose concurrency is too low to split (limit 1).
  const excludeQueues = (process.env.EXCLUDE_QUEUE || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  // How many worker servers share each (non-excluded) queue. Per-server
  // concurrency is divided by this so the GLOBAL concurrency stays correct.
  // 1 server => 1 (full), 2 servers => 2 (half each), 3 servers => 3, etc.
  const divider = Math.max(
    1,
    Number(process.env.WORKER_CONCURRENCY_DIVIDER) || 1
  );

  // Unified-queue mode is ours: with TEMPORAL_UNIFIED_QUEUE set, every provider's
  // activities run on the single main queue, so this deployment boots one worker
  // instead of one per provider (33 -> 1 at our scale). The cap of 5 is the
  // 6-user tuning, kept deliberately.
  const queues = isUnifiedQueue()
    ? [{ identifier: MAIN_TASK_QUEUE, maxConcurrentJob: 5 }]
    : [
        { identifier: MAIN_TASK_QUEUE, maxConcurrentJob: 5 },
        ...socialIntegrationList,
      ].filter((f) => f.identifier.indexOf('-') === -1);

  return TemporalModule.register({
    isGlobal: true,
    connection: {
      address: process.env.TEMPORAL_ADDRESS || 'localhost:7233',
      ...(process.env.TEMPORAL_TLS === 'true' ? { tls: true } : {}),
      ...(process.env.TEMPORAL_API_KEY
        ? { apiKey: process.env.TEMPORAL_API_KEY }
        : {}),
      namespace: process.env.TEMPORAL_NAMESPACE || 'default',
    },
    taskQueue: MAIN_TASK_QUEUE,
    logLevel: 'error',
    ...(isWorkers
      ? {
          workers: queues
            .map((integration) => ({
              integration,
              taskQueue: integration.identifier.split('-')[0],
            }))
            .filter(({ taskQueue }) => !excludeQueues.includes(taskQueue))
            .map(({ integration, taskQueue }) => {
              // Split the per-provider cap across the servers sharing this
              // queue. Floor (never below 1) so the global total never exceeds
              // the provider's limit. Providers whose limit is smaller than the
              // server count must be pinned via EXCLUDE_QUEUE instead.
              const concurrency = integration.maxConcurrentJob
                ? Math.max(
                    1,
                    Math.floor(integration.maxConcurrentJob / divider)
                  )
                : undefined;

              // Workflows only ever run on the main queue; other Workers are
              // activity-only, so skip the workflow bundle (webpack build,
              // workflow thread + V8 isolate, sticky cache) on them. This is
              // upstream's optimisation and it matches our idle-memory work —
              // workflowSource() is ours and stays, since this fork ships a
              // prebuilt workflow bundle.
              return {
                taskQueue,
                ...(taskQueue === MAIN_TASK_QUEUE ? workflowSource(path) : {}),
                activityClasses: activityClasses!,
                autoStart: true,
                workerOptions: {
                  ...workerMemoryOptions,
                  maxConcurrentActivityTaskExecutions: concurrency ?? 1000000,
                  // By default the SDK throttles heartbeat sends to 60s, so
                  // against the workflow's heartbeatTimeout one dropped send
                  // or a minute of event-loop lag eats most of the margin.
                  // Sending every 15s keeps the recorded heartbeat fresh even
                  // when individual sends fail or fire late.
                  maxHeartbeatThrottleInterval: '15s',
                },
              };
            }),
        }
      : {}),
  });
};
