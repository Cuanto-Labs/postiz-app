import { IdempotencyRepository } from '@gitroom/nestjs-libraries/mobile/idempotency.repository';

function makeRepo() {
  const idempotencyKey = {
    findFirst: jest.fn(),
    create: jest.fn(),
    deleteMany: jest.fn(),
  };
  const repo = new IdempotencyRepository({
    model: { idempotencyKey },
  } as any);
  return { repo, idempotencyKey };
}

describe('IdempotencyRepository', () => {
  it('find queries by organizationId and key', async () => {
    const { repo, idempotencyKey } = makeRepo();
    await repo.find('org1', 'key1');
    expect(idempotencyKey.findFirst).toHaveBeenCalledWith({
      where: { organizationId: 'org1', key: 'key1' },
    });
  });

  it('save calls prisma create with data', async () => {
    const { repo, idempotencyKey } = makeRepo();
    const data = {
      organizationId: 'org1',
      key: 'key1',
      method: 'POST',
      path: '/posts',
      requestHash: 'hash1',
      statusCode: 201,
      response: '{}',
      expiresAt: new Date('2026-01-01'),
    };
    await repo.save(data);
    expect(idempotencyKey.create).toHaveBeenCalledWith({ data });
  });

  it('purgeExpired deletes rows with expiresAt before now', async () => {
    const { repo, idempotencyKey } = makeRepo();
    const now = new Date('2026-01-01');
    await repo.purgeExpired(now);
    expect(idempotencyKey.deleteMany).toHaveBeenCalledWith({
      where: { expiresAt: { lt: now } },
    });
  });
});
