import { PushDeviceRepository } from '@gitroom/nestjs-libraries/mobile/push/push-device.repository';

function makeRepo() {
  const pushDevice = {
    upsert: jest.fn(),
    findFirst: jest.fn(),
    deleteMany: jest.fn(),
    updateMany: jest.fn(),
    findMany: jest.fn(),
  };
  const repo = new PushDeviceRepository({
    model: { pushDevice },
  } as any);
  return { repo, pushDevice };
}

describe('PushDeviceRepository', () => {
  it('upsertByToken upserts by apnsToken with create and update data', async () => {
    const { repo, pushDevice } = makeRepo();
    const data = {
      userId: 'u1',
      organizationId: 'o1',
      apnsToken: 'token1',
      environment: 'production',
      bundleId: 'com.cuanto.socials',
      locale: 'en-US',
      timezone: 'America/New_York',
      prefs: { marketing: true },
    };
    await repo.upsertByToken(data);
    expect(pushDevice.upsert).toHaveBeenCalledWith({
      where: { apnsToken: 'token1' },
      create: expect.objectContaining({
        userId: 'u1',
        organizationId: 'o1',
        apnsToken: 'token1',
        environment: 'production',
        bundleId: 'com.cuanto.socials',
        locale: 'en-US',
        timezone: 'America/New_York',
        prefs: { marketing: true },
      }),
      update: expect.objectContaining({
        userId: 'u1',
        organizationId: 'o1',
        environment: 'production',
        bundleId: 'com.cuanto.socials',
        locale: 'en-US',
        timezone: 'America/New_York',
        prefs: { marketing: true },
        lastSeenAt: expect.any(Date),
        disabledAt: null,
      }),
    });
  });

  it('findByToken queries by userId and apnsToken', async () => {
    const { repo, pushDevice } = makeRepo();
    await repo.findByToken('u1', 'token1');
    expect(pushDevice.findFirst).toHaveBeenCalledWith({
      where: { userId: 'u1', apnsToken: 'token1' },
    });
  });

  it('deleteByToken deletes by userId and apnsToken', async () => {
    const { repo, pushDevice } = makeRepo();
    await repo.deleteByToken('u1', 'token1');
    expect(pushDevice.deleteMany).toHaveBeenCalledWith({
      where: { userId: 'u1', apnsToken: 'token1' },
    });
  });

  it('updatePrefs updates prefs for userId and apnsToken', async () => {
    const { repo, pushDevice } = makeRepo();
    await repo.updatePrefs('u1', 'token1', { marketing: false });
    expect(pushDevice.updateMany).toHaveBeenCalledWith({
      where: { userId: 'u1', apnsToken: 'token1' },
      data: { prefs: { marketing: false } },
    });
  });

  it('disableByToken sets disabledAt', async () => {
    const { repo, pushDevice } = makeRepo();
    await repo.disableByToken('token1');
    expect(pushDevice.updateMany).toHaveBeenCalledWith({
      where: { apnsToken: 'token1' },
      data: { disabledAt: expect.any(Date) },
    });
  });

  it('listActiveForUsers filters by userId in and disabledAt null', async () => {
    const { repo, pushDevice } = makeRepo();
    await repo.listActiveForUsers(['u1', 'u2']);
    expect(pushDevice.findMany).toHaveBeenCalledWith({
      where: {
        userId: { in: ['u1', 'u2'] },
        disabledAt: null,
      },
    });
  });

  it('deleteAllForUser deletes all rows for userId', async () => {
    const { repo, pushDevice } = makeRepo();
    await repo.deleteAllForUser('u1');
    expect(pushDevice.deleteMany).toHaveBeenCalledWith({
      where: { userId: 'u1' },
    });
  });
});
