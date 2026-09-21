import 'reflect-metadata';

jest.mock('nestjs-temporal-core', () => ({
  TemporalService: class TemporalService {},
}));
jest.mock('@gitroom/nestjs-libraries/services/email.service', () => ({
  EmailService: class EmailService {},
}));
jest.mock('@gitroom/nestjs-libraries/services/stripe.service', () => ({
  StripeService: class StripeService {},
}));
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/organizations/organization.repository',
  () => ({
    OrganizationRepository: class OrganizationRepository {},
  })
);
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/integrations/integration.repository',
  () => ({
    IntegrationRepository: class IntegrationRepository {},
  })
);
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/subscriptions/subscription.service',
  () => ({
    SubscriptionService: class SubscriptionService {},
  })
);

import { MobileAccountService } from './mobile-account.service';

function makeOrg(id: string, role: 'SUPERADMIN' | 'USER') {
  return { id, name: `org-${id}`, users: [{ role, disabled: false }] };
}

function asyncIterableOf<T>(items: T[]) {
  return {
    [Symbol.asyncIterator]: async function* () {
      for (const item of items) {
        yield item;
      }
    },
  };
}

function makeDeps() {
  const organizationRepository = {
    getOrgsByUserId: jest.fn(),
    deleteOrganization: jest.fn().mockResolvedValue(undefined),
    deleteTeamMember: jest.fn().mockResolvedValue(undefined),
  };
  const integrationRepository = {
    deleteIntegrationsForAccount: jest.fn().mockResolvedValue(undefined),
  };
  const accountDeletionRepository = {
    countOtherAdmins: jest.fn(),
    listRunningPostIds: jest.fn().mockResolvedValue([]),
    listProcessingMediaIds: jest.fn().mockResolvedValue([]),
    softDeleteMedia: jest.fn().mockResolvedValue(undefined),
    revokeUserSessions: jest.fn().mockResolvedValue({ sessions: 1, devices: 1 }),
    anonymizeUser: jest.fn().mockResolvedValue(undefined),
    writeAudit: jest.fn().mockResolvedValue(undefined),
  };
  const subscriptionService = {
    getSubscriptionByOrganizationId: jest.fn().mockResolvedValue(null),
  };
  const stripeService = {
    setToCancel: jest.fn().mockResolvedValue(undefined),
  };
  const emailService = {
    hasProvider: jest.fn().mockReturnValue(true),
    sendEmail: jest.fn().mockResolvedValue(undefined),
  };
  const workflowHandle = {
    terminate: jest.fn().mockResolvedValue(undefined),
    describe: jest.fn().mockResolvedValue({ status: { name: 'RUNNING' } }),
  };
  const workflowList = jest.fn().mockReturnValue(asyncIterableOf([]));
  const temporalService = {
    client: {
      getWorkflowHandle: jest.fn().mockResolvedValue(workflowHandle),
      getRawClient: jest.fn().mockReturnValue({
        workflow: { list: workflowList },
      }),
    },
  };

  const service = new MobileAccountService(
    organizationRepository as any,
    integrationRepository as any,
    accountDeletionRepository as any,
    subscriptionService as any,
    stripeService as any,
    emailService as any,
    temporalService as any
  );

  return {
    service,
    organizationRepository,
    integrationRepository,
    accountDeletionRepository,
    subscriptionService,
    stripeService,
    emailService,
    temporalService,
    workflowHandle,
    workflowList,
  };
}

describe('MobileAccountService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('sole-admin org: terminates running posts, deletes integrations + organization', async () => {
    const deps = makeDeps();
    const org = makeOrg('org1', 'SUPERADMIN');
    deps.organizationRepository.getOrgsByUserId.mockResolvedValue([org]);
    deps.accountDeletionRepository.countOtherAdmins.mockResolvedValue(0);
    deps.accountDeletionRepository.listRunningPostIds.mockResolvedValue([
      { id: 'p1' },
    ]);
    deps.workflowList.mockReturnValue(
      asyncIterableOf([{ workflowId: 'post_p1_abc123' }])
    );

    await deps.service.deleteAccount('user1', 'user@example.com');

    expect(deps.workflowList).toHaveBeenCalledWith({
      query: 'postId="p1" AND ExecutionStatus="Running"',
    });
    expect(deps.temporalService.client.getWorkflowHandle).toHaveBeenCalledWith(
      'post_p1_abc123'
    );
    expect(deps.workflowHandle.describe).toHaveBeenCalled();
    expect(deps.workflowHandle.terminate).toHaveBeenCalledWith();
    expect(
      deps.integrationRepository.deleteIntegrationsForAccount
    ).toHaveBeenCalledWith('org1');
    expect(
      deps.organizationRepository.deleteOrganization
    ).toHaveBeenCalledWith('org1');
    expect(deps.organizationRepository.deleteTeamMember).not.toHaveBeenCalled();
  });

  it('shared-admin org: only leaves the team, does not delete', async () => {
    const deps = makeDeps();
    const org = makeOrg('org2', 'SUPERADMIN');
    deps.organizationRepository.getOrgsByUserId.mockResolvedValue([org]);
    deps.accountDeletionRepository.countOtherAdmins.mockResolvedValue(1);

    await deps.service.deleteAccount('user1', 'user@example.com');

    expect(deps.organizationRepository.deleteTeamMember).toHaveBeenCalledWith(
      'org2',
      'user1'
    );
    expect(
      deps.organizationRepository.deleteOrganization
    ).not.toHaveBeenCalled();
    expect(
      deps.integrationRepository.deleteIntegrationsForAccount
    ).not.toHaveBeenCalled();
  });

  it('revokes sessions, writes audit, and anonymizes after emailing the original address', async () => {
    const deps = makeDeps();
    const org = makeOrg('org3', 'SUPERADMIN');
    deps.organizationRepository.getOrgsByUserId.mockResolvedValue([org]);
    deps.accountDeletionRepository.countOtherAdmins.mockResolvedValue(0);

    await deps.service.deleteAccount('user1', 'original@example.com');

    expect(
      deps.accountDeletionRepository.revokeUserSessions
    ).toHaveBeenCalledWith('user1');
    expect(deps.accountDeletionRepository.writeAudit).toHaveBeenCalledWith(
      expect.objectContaining({
        orgIdsDeleted: ['org3'],
        orgIdsLeft: [],
        source: 'mobile',
      })
    );
    expect(deps.emailService.sendEmail).toHaveBeenCalledWith(
      'original@example.com',
      expect.any(String),
      expect.any(String),
      'bottom'
    );

    const sendEmailOrder =
      deps.emailService.sendEmail.mock.invocationCallOrder[0];
    const anonymizeOrder =
      deps.accountDeletionRepository.anonymizeUser.mock.invocationCallOrder[0];
    expect(sendEmailOrder).toBeLessThan(anonymizeOrder);
  });

  it('does not abort the cascade when Temporal or Stripe throw', async () => {
    const deps = makeDeps();
    const org = makeOrg('org4', 'SUPERADMIN');
    deps.organizationRepository.getOrgsByUserId.mockResolvedValue([org]);
    deps.accountDeletionRepository.countOtherAdmins.mockResolvedValue(0);
    deps.accountDeletionRepository.listRunningPostIds.mockResolvedValue([
      { id: 'p1' },
    ]);
    deps.workflowList.mockReturnValue(
      asyncIterableOf([{ workflowId: 'post_p1' }])
    );
    deps.temporalService.client.getWorkflowHandle.mockRejectedValue(
      new Error('temporal down')
    );
    deps.subscriptionService.getSubscriptionByOrganizationId.mockResolvedValue(
      { id: 'sub1' }
    );
    deps.stripeService.setToCancel.mockRejectedValue(new Error('stripe down'));

    const result = await deps.service.deleteAccount(
      'user1',
      'user@example.com'
    );

    expect(
      deps.integrationRepository.deleteIntegrationsForAccount
    ).toHaveBeenCalledWith('org4');
    expect(
      deps.organizationRepository.deleteOrganization
    ).toHaveBeenCalledWith('org4');
    expect(result).toEqual({
      deletedOrgs: [{ id: 'org4', name: 'org-org4' }],
      leftOrgs: [],
    });
  });
});
