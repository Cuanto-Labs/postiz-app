import { continueAsNew, proxyActivities, sleep } from '@temporalio/workflow';
import { PostActivity } from '@gitroom/orchestrator/activities/post.activity';

const { searchForMissingThreeHoursPosts } = proxyActivities<PostActivity>({
  startToCloseTimeout: '10 minute',
  retry: {
    maximumAttempts: 3,
    backoffCoefficient: 1,
    initialInterval: '2 minutes',
  },
});

// Roll over daily so history stays small; one run used to grow forever
// and would hit Temporal's 51,200-event hard limit.
const ITERATIONS_PER_RUN = 24;

export async function missingPostWorkflow(continued = false) {
  if (!continued) {
    await searchForMissingThreeHoursPosts();
  }
  for (let i = 0; i < ITERATIONS_PER_RUN; i++) {
    await sleep('1 hour');
    await searchForMissingThreeHoursPosts();
  }
  await continueAsNew<typeof missingPostWorkflow>(true);
}
