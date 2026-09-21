import { MobileSessionRepository } from '@gitroom/nestjs-libraries/mobile/mobile-session.repository';

function makeRepo() {
  const mobileSession = {
    create: jest.fn(),
    findFirst: jest.fn(),
    update: jest.fn(),
    updateMany: jest.fn(),
    findMany: jest.fn(),
  };
  const repo = new MobileSessionRepository({
    model: { mobileSession },
  } as any);
  return { repo, mobileSession };
}

describe('MobileSessionRepository', () => {
  it('create calls prisma create with data', async () => {
    const { repo, mobileSession } = makeRepo();
    const data = {
      userId: 'u1',
      familyId: 'f1',
      deviceId: 'd1',
      deviceName: 'iPhone',
      platform: 'ios',
      refreshTokenHash: 'hash1',
      expiresAt: new Date('2026-01-01'),
    };
    await repo.create(data);
    expect(mobileSession.create).toHaveBeenCalledWith({ data });
  });

  it('findByRefreshHash queries by refreshTokenHash', async () => {
    const { repo, mobileSession } = makeRepo();
    await repo.findByRefreshHash('hash1');
    expect(mobileSession.findFirst).toHaveBeenCalledWith({
      where: { refreshTokenHash: 'hash1' },
    });
  });

  it('findByPreviousHash queries by previousTokenHash', async () => {
    const { repo, mobileSession } = makeRepo();
    await repo.findByPreviousHash('hash2');
    expect(mobileSession.findFirst).toHaveBeenCalledWith({
      where: { previousTokenHash: 'hash2' },
    });
  });

  it('findById queries by id', async () => {
    const { repo, mobileSession } = makeRepo();
    await repo.findById('id1');
    expect(mobileSession.findFirst).toHaveBeenCalledWith({
      where: { id: 'id1' },
    });
  });

  it('rotate sets previousTokenHash to oldHash and refreshTokenHash to newHash', async () => {
    const { repo, mobileSession } = makeRepo();
    const expiresAt = new Date('2026-02-01');
    await repo.rotate('id1', 'oldHash', 'newHash', expiresAt);
    expect(mobileSession.update).toHaveBeenCalledWith({
      where: { id: 'id1' },
      data: expect.objectContaining({
        previousTokenHash: 'oldHash',
        refreshTokenHash: 'newHash',
        expiresAt,
        lastUsedAt: expect.any(Date),
      }),
    });
  });

  it('touch updates lastUsedAt', async () => {
    const { repo, mobileSession } = makeRepo();
    await repo.touch('id1');
    expect(mobileSession.update).toHaveBeenCalledWith({
      where: { id: 'id1' },
      data: { lastUsedAt: expect.any(Date) },
    });
  });

  it('revoke sets revokedAt', async () => {
    const { repo, mobileSession } = makeRepo();
    await repo.revoke('id1');
    expect(mobileSession.update).toHaveBeenCalledWith({
      where: { id: 'id1' },
      data: { revokedAt: expect.any(Date) },
    });
  });

  it('revokeFamily filters by familyId and revokedAt null', async () => {
    const { repo, mobileSession } = makeRepo();
    await repo.revokeFamily('f1');
    expect(mobileSession.updateMany).toHaveBeenCalledWith({
      where: { familyId: 'f1', revokedAt: null },
      data: { revokedAt: expect.any(Date) },
    });
  });

  it('revokeAllForUser filters by userId and revokedAt null', async () => {
    const { repo, mobileSession } = makeRepo();
    await repo.revokeAllForUser('u1');
    expect(mobileSession.updateMany).toHaveBeenCalledWith({
      where: { userId: 'u1', revokedAt: null },
      data: { revokedAt: expect.any(Date) },
    });
  });

  it('listActiveForUser filters expiresAt gt and selects fields', async () => {
    const { repo, mobileSession } = makeRepo();
    await repo.listActiveForUser('u1');
    expect(mobileSession.findMany).toHaveBeenCalledWith({
      where: {
        userId: 'u1',
        revokedAt: null,
        expiresAt: { gt: expect.any(Date) },
      },
      orderBy: { lastUsedAt: 'desc' },
      select: {
        id: true,
        deviceId: true,
        deviceName: true,
        platform: true,
        createdAt: true,
        lastUsedAt: true,
      },
    });
  });
});
