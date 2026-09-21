import { AccountDeletionRepository } from '@gitroom/nestjs-libraries/mobile/account/account-deletion.repository';

function makeRepo() {
  const user = { update: jest.fn() };
  const userOrganization = { count: jest.fn() };
  const post = { findMany: jest.fn() };
  const media = { findMany: jest.fn(), updateMany: jest.fn() };
  const mobileSession = { deleteMany: jest.fn().mockResolvedValue({ count: 1 }) };
  const pushDevice = { deleteMany: jest.fn().mockResolvedValue({ count: 2 }) };
  const accountDeletionAudit = { create: jest.fn() };

  const repo = new AccountDeletionRepository(
    { model: { user } } as any,
    { model: { userOrganization } } as any,
    { model: { post } } as any,
    { model: { media } } as any,
    { model: { mobileSession } } as any,
    { model: { pushDevice } } as any,
    { model: { accountDeletionAudit } } as any
  );

  return {
    repo,
    user,
    userOrganization,
    post,
    media,
    mobileSession,
    pushDevice,
    accountDeletionAudit,
  };
}

describe('AccountDeletionRepository', () => {
  it('countOtherAdmins queries SUPERADMIN role excluding userId, not disabled', async () => {
    const { repo, userOrganization } = makeRepo();
    await repo.countOtherAdmins('org1', 'user1');
    expect(userOrganization.count).toHaveBeenCalledWith({
      where: {
        organizationId: 'org1',
        role: 'SUPERADMIN',
        userId: { not: 'user1' },
        disabled: false,
      },
    });
  });

  it('listRunningPostIds queries QUEUE posts for given orgs', async () => {
    const { repo, post } = makeRepo();
    await repo.listRunningPostIds(['org1', 'org2']);
    expect(post.findMany).toHaveBeenCalledWith({
      select: { id: true },
      where: {
        organizationId: { in: ['org1', 'org2'] },
        deletedAt: null,
        state: { in: ['QUEUE'] },
      },
    });
  });

  it('listProcessingMediaIds queries processing media for given orgs', async () => {
    const { repo, media } = makeRepo();
    await repo.listProcessingMediaIds(['org1']);
    expect(media.findMany).toHaveBeenCalledWith({
      select: { id: true },
      where: {
        organizationId: { in: ['org1'] },
        status: 'processing',
      },
    });
  });

  it('softDeleteMedia sets deletedAt for org media', async () => {
    const { repo, media } = makeRepo();
    await repo.softDeleteMedia('org1');
    expect(media.updateMany).toHaveBeenCalledWith({
      where: { organizationId: 'org1' },
      data: { deletedAt: expect.any(Date) },
    });
  });

  it('revokeUserSessions deletes mobile sessions and push devices, returns counts', async () => {
    const { repo, mobileSession, pushDevice } = makeRepo();
    const result = await repo.revokeUserSessions('user1');
    expect(mobileSession.deleteMany).toHaveBeenCalledWith({
      where: { userId: 'user1' },
    });
    expect(pushDevice.deleteMany).toHaveBeenCalledWith({
      where: { userId: 'user1' },
    });
    expect(result).toEqual({ sessions: 1, devices: 2 });
  });

  it('anonymizeUser scrubs identifying fields using hash', async () => {
    const { repo, user } = makeRepo();
    await repo.anonymizeUser('user1', 'abc123');
    expect(user.update).toHaveBeenCalledWith({
      where: { id: 'user1' },
      data: {
        email: 'deleted+abc123@deleted.invalid',
        name: null,
        lastName: null,
        pictureId: null,
        password: null,
        providerId: 'deleted-abc123',
        bio: null,
        activated: false,
        deletedAt: expect.any(Date),
      },
    });
  });

  it('writeAudit creates audit row without storing email', async () => {
    const { repo, accountDeletionAudit } = makeRepo();
    await repo.writeAudit({
      userIdHash: 'hash1',
      orgIdsDeleted: ['org1'],
      orgIdsLeft: ['org2'],
      source: 'mobile',
    });
    const call = accountDeletionAudit.create.mock.calls[0][0];
    expect(call).toEqual({
      data: {
        userIdHash: 'hash1',
        orgIdsDeleted: ['org1'],
        orgIdsLeft: ['org2'],
        source: 'mobile',
      },
    });
    expect(call.data.email).toBeUndefined();
  });
});
