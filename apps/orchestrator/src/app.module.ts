import { Module } from '@nestjs/common';
import { join } from 'node:path';
import { PostActivity } from '@gitroom/orchestrator/activities/post.activity';
import { getTemporalModule } from '@gitroom/nestjs-libraries/temporal/temporal.module';
import { DatabaseModule } from '@gitroom/nestjs-libraries/database/prisma/database.module';
import { AutopostService } from '@gitroom/nestjs-libraries/database/prisma/autopost/autopost.service';
import { EmailActivity } from '@gitroom/orchestrator/activities/email.activity';
import { IntegrationsActivity } from '@gitroom/orchestrator/activities/integrations.activity';
import { HealthController } from '@gitroom/orchestrator/health.controller';

const activities = [
  PostActivity,
  AutopostService,
  EmailActivity,
  IntegrationsActivity,
];

/**
 * Runtime fallback for the workers when the prebuilt workflow bundle is absent.
 *
 * `require.resolve` runs at load time and throws when the workflow tree wasn't
 * emitted beside this module — which is the case when the backend hosts this
 * module in-process, since tsc follows type imports and not `require.resolve`.
 * Resolve leniently and let `getTemporalModule` decide: it prefers the bundle,
 * and only falls back to bundling from source when one is available.
 */
const workflowsPath = [
  () => require.resolve('./workflows'),
  () =>
    require.resolve(
      join(process.cwd(), 'apps/orchestrator/dist/apps/orchestrator/src/workflows')
    ),
].reduce<string | undefined>((found, resolveCandidate) => {
  if (found) {
    return found;
  }

  try {
    return resolveCandidate();
  } catch {
    return undefined;
  }
}, undefined);
@Module({
  imports: [
    DatabaseModule,
    getTemporalModule(true, workflowsPath, activities),
  ],
  controllers: [HealthController],
  providers: [...activities],
  get exports() {
    return [...this.providers, ...this.imports];
  },
})
export class AppModule {}
