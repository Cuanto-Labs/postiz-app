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
          workers: queues.map((integration) => ({
            taskQueue: integration.identifier.split('-')[0],
            ...workflowSource(path),
            activityClasses: activityClasses!,
            autoStart: true,
            workerOptions: {
              ...workerMemoryOptions,
              ...(integration.maxConcurrentJob
                ? {
                    maxConcurrentActivityTaskExecutions:
                      integration.maxConcurrentJob,
                  }
                : {}),
            },
          })),
        }
      : {}),
  });
};
