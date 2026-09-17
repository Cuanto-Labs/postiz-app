import 'reflect-metadata';

import { createHash } from 'crypto';
import { lastValueFrom, of } from 'rxjs';
import {
  BadRequestException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { MobileIdempotencyInterceptor } from '@gitroom/backend/api/routes/mobile/mobile-idempotency.interceptor';

describe('MobileIdempotencyInterceptor', () => {
  const org = { id: 'org-1' };
  const user = { id: 'user-1' };

  const makeRequest = (overrides: any = {}) => ({
    method: 'POST',
    path: '/mobile/v1/posts',
    body: { a: 1 },
    headers: {},
    org,
    user,
    ...overrides,
  });

  const hashFor = (req: any) =>
    createHash('sha256')
      .update(req.method + req.path + JSON.stringify(req.body || {}))
      .digest('hex');

  const makeContext = (req: any, res: any) => ({
    switchToHttp: () => ({
      getRequest: () => req,
      getResponse: () => res,
    }),
  });

  const makeInterceptor = (repoOverrides: any = {}) => {
    const idempotencyRepository = {
      find: jest.fn().mockResolvedValue(null),
      save: jest.fn().mockResolvedValue(undefined),
      ...repoOverrides,
    };
    const interceptor = new MobileIdempotencyInterceptor(
      idempotencyRepository as any
    );

    return { interceptor, idempotencyRepository };
  };

  it('no header passes through and never calls the repository', async () => {
    const { interceptor, idempotencyRepository } = makeInterceptor();
    const req = makeRequest();
    const res = { status: jest.fn() };
    const next = { handle: jest.fn().mockReturnValue(of({ ok: true })) };

    const result = await interceptor.intercept(
      makeContext(req, res) as any,
      next as any
    );

    await expect(lastValueFrom(result)).resolves.toEqual({ ok: true });
    expect(next.handle).toHaveBeenCalled();
    expect(idempotencyRepository.find).not.toHaveBeenCalled();
    expect(idempotencyRepository.save).not.toHaveBeenCalled();
  });

  it('miss stores a row with org id and request hash', async () => {
    const { interceptor, idempotencyRepository } = makeInterceptor();
    const req = makeRequest({ headers: { 'idempotency-key': 'abcdefgh' } });
    const res = { status: jest.fn(), statusCode: 200 };
    const next = { handle: jest.fn().mockReturnValue(of({ ok: true })) };

    const result = await interceptor.intercept(
      makeContext(req, res) as any,
      next as any
    );

    await lastValueFrom(result);

    expect(idempotencyRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        organizationId: org.id,
        key: `${user.id}:abcdefgh`,
        requestHash: hashFor(req),
        statusCode: 200,
        response: JSON.stringify({ ok: true }),
      })
    );
  });

  it('two different users reusing the same key in the same org do not replay each other', async () => {
    const userA = { id: 'user-a' };
    const userB = { id: 'user-b' };
    const reqA = makeRequest({
      headers: { 'idempotency-key': 'abcdefgh' },
      user: userA,
    });
    const reqB = makeRequest({
      headers: { 'idempotency-key': 'abcdefgh' },
      user: userB,
    });

    // Simulate the repository: userA already has a stored row for this key,
    // userB does not.
    const find = jest.fn(async (_orgId: string, key: string) =>
      key === `${userA.id}:abcdefgh`
        ? {
            requestHash: hashFor(reqA),
            statusCode: 201,
            response: JSON.stringify({ owner: 'a' }),
          }
        : null
    );
    const { interceptor, idempotencyRepository } = makeInterceptor({ find });

    const resA = { status: jest.fn() };
    const nextA = { handle: jest.fn().mockReturnValue(of({ owner: 'a' })) };
    const resultA = await interceptor.intercept(
      makeContext(reqA, resA) as any,
      nextA as any
    );
    await expect(lastValueFrom(resultA)).resolves.toEqual({ owner: 'a' });
    expect(nextA.handle).not.toHaveBeenCalled();

    const resB = { status: jest.fn(), statusCode: 200 };
    const nextB = { handle: jest.fn().mockReturnValue(of({ owner: 'b' })) };
    const resultB = await interceptor.intercept(
      makeContext(reqB, resB) as any,
      nextB as any
    );
    await expect(lastValueFrom(resultB)).resolves.toEqual({ owner: 'b' });
    expect(nextB.handle).toHaveBeenCalled();
    expect(idempotencyRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        key: `${userB.id}:abcdefgh`,
        response: JSON.stringify({ owner: 'b' }),
      })
    );
  });

  it('hit replays the stored body and status without calling the handler', async () => {
    const req = makeRequest({ headers: { 'idempotency-key': 'abcdefgh' } });
    const existing = {
      requestHash: hashFor(req),
      statusCode: 201,
      response: JSON.stringify({ cached: true }),
    };
    const { interceptor, idempotencyRepository } = makeInterceptor({
      find: jest.fn().mockResolvedValue(existing),
    });
    const res = { status: jest.fn() };
    const next = { handle: jest.fn().mockReturnValue(of({ ok: true })) };

    const result = await interceptor.intercept(
      makeContext(req, res) as any,
      next as any
    );

    await expect(lastValueFrom(result)).resolves.toEqual({ cached: true });
    expect(res.status).toHaveBeenCalledWith(201);
    expect(next.handle).not.toHaveBeenCalled();
    expect(idempotencyRepository.save).not.toHaveBeenCalled();
  });

  it('hash mismatch throws 422', async () => {
    const req = makeRequest({ headers: { 'idempotency-key': 'abcdefgh' } });
    const { interceptor } = makeInterceptor({
      find: jest.fn().mockResolvedValue({
        requestHash: 'different-hash',
        statusCode: 200,
        response: JSON.stringify({}),
      }),
    });
    const res = { status: jest.fn() };
    const next = { handle: jest.fn().mockReturnValue(of({ ok: true })) };

    await expect(
      interceptor.intercept(makeContext(req, res) as any, next as any)
    ).rejects.toThrow(UnprocessableEntityException);
  });

  it('bad key length throws 400', async () => {
    const { interceptor } = makeInterceptor();
    const req = makeRequest({ headers: { 'idempotency-key': 'short' } });
    const res = { status: jest.fn() };
    const next = { handle: jest.fn().mockReturnValue(of({ ok: true })) };

    await expect(
      interceptor.intercept(makeContext(req, res) as any, next as any)
    ).rejects.toThrow(BadRequestException);
  });
});
