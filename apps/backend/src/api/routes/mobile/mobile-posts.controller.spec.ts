import 'reflect-metadata';

// PostsService transitively imports IntegrationManager -> the nostr provider,
// which ships ESM and cannot be required under ts-jest's CJS transform. The
// controller only needs the class reference for Nest's design:paramtypes
// metadata; every method is mocked below, so a lightweight stand-in avoids
// the ESM import entirely (same pattern as mobile-config.controller.spec.ts).
jest.mock('@gitroom/nestjs-libraries/integrations/integration.manager', () => ({
  IntegrationManager: class IntegrationManager {},
}));

import { MobilePostsController } from '@gitroom/backend/api/routes/mobile/mobile-posts.controller';
import { MobileIdempotencyInterceptor } from '@gitroom/backend/api/routes/mobile/mobile-idempotency.interceptor';
import { PostValidationException } from '@gitroom/backend/api/routes/posts.validation.exception';
import { CHECK_POLICIES_KEY } from '@gitroom/backend/services/auth/permissions/permissions.ability';

describe('MobilePostsController', () => {
  const org = { id: 'org-1' };

  const validRow = {
    identifier: 'integration-1',
    name: 'channel',
    valid: true,
    errors: true,
    tooLong: false,
    emptyContent: false,
    settingsError: '',
  };

  const makeController = () => {
    const postsService = {
      getPostsMinified: jest.fn(),
      getPostsByGroup: jest.fn(),
      validatePosts: jest.fn().mockResolvedValue([validRow]),
      mapTypeToPost: jest.fn().mockImplementation((body) => body),
      createPost: jest.fn().mockResolvedValue([{ id: 'post-1' }]),
      deletePost: jest.fn().mockResolvedValue(undefined),
      changeDate: jest.fn().mockResolvedValue(undefined),
    };

    const controller = new MobilePostsController(postsService as any);

    return { controller, postsService };
  };

  it('exposes the /mobile/v1/posts path', () => {
    expect(Reflect.getMetadata('path', MobilePostsController)).toBe(
      '/mobile/v1/posts'
    );
  });

  it('list maps from/to/customer to startDate/endDate/customer', async () => {
    const { controller, postsService } = makeController();
    postsService.getPostsMinified.mockResolvedValue([{ id: 'post-1' }]);

    const result = await controller.list(org as any, {
      from: '2026-01-01',
      to: '2026-01-31',
      customer: 'cust-1',
    } as any);

    expect(postsService.getPostsMinified).toHaveBeenCalledWith('org-1', {
      startDate: '2026-01-01',
      endDate: '2026-01-31',
      customer: 'cust-1',
    });
    expect(result).toEqual({ posts: [{ id: 'post-1' }] });
  });

  it('detail delegates to getPostsByGroup', async () => {
    const { controller, postsService } = makeController();
    const groupResult = { group: 'group-1', posts: [{ id: 'post-1' }] };
    postsService.getPostsByGroup.mockResolvedValue(groupResult);

    const result = await controller.detail(org as any, 'group-1');

    expect(postsService.getPostsByGroup).toHaveBeenCalledWith(
      'org-1',
      'group-1'
    );
    expect(result).toEqual(groupResult);
  });

  it('detail throws 404 when the group has no posts', async () => {
    const { controller, postsService } = makeController();
    postsService.getPostsByGroup.mockResolvedValue({
      group: undefined,
      posts: [],
    });

    await expect(controller.detail(org as any, 'missing')).rejects.toMatchObject(
      {
        status: 404,
        response: { msg: 'Post not found' },
      }
    );
  });

  it('create applies MobileIdempotencyInterceptor', () => {
    const { controller } = makeController();
    const interceptors = Reflect.getMetadata(
      '__interceptors__',
      controller.create
    );
    expect(interceptors).toContain(MobileIdempotencyInterceptor);
  });

  it('create rejects emptyContent posts via PostValidationException', async () => {
    const { controller, postsService } = makeController();
    postsService.validatePosts.mockResolvedValue([
      { ...validRow, emptyContent: true },
    ]);

    await expect(
      controller.create(org as any, { posts: [{}] })
    ).rejects.toBeInstanceOf(PostValidationException);
    expect(postsService.createPost).not.toHaveBeenCalled();
  });

  it('create passes WEB as the creation method', async () => {
    const { controller, postsService } = makeController();
    const rawBody = { posts: [{}], type: 'now' };

    await controller.create(org as any, rawBody);

    expect(postsService.createPost).toHaveBeenCalledWith(
      'org-1',
      rawBody,
      'WEB'
    );
  });

  it('update carries the same policy metadata as create (plan-limit bypass guard)', () => {
    const { controller } = makeController();
    const createPolicies = Reflect.getMetadata(
      CHECK_POLICIES_KEY,
      controller.create
    );
    const updatePolicies = Reflect.getMetadata(
      CHECK_POLICIES_KEY,
      controller.update
    );

    expect(updatePolicies).toEqual(createPolicies);
    expect(updatePolicies).toBeDefined();
  });

  it('update forces the group onto every post and defaults type to update', async () => {
    const { controller, postsService } = makeController();
    const rawBody = { posts: [{ group: 'old' }, { group: 'old' }] };

    await controller.update(org as any, 'group-1', rawBody);

    expect(rawBody.posts.every((p: any) => p.group === 'group-1')).toBe(true);
    expect(postsService.createPost).toHaveBeenCalledWith(
      'org-1',
      expect.objectContaining({ type: 'update' }),
      'WEB'
    );
  });

  it('reschedule calls changeDate once per root post with the update default', async () => {
    const { controller, postsService } = makeController();
    postsService.getPostsByGroup.mockResolvedValue({
      group: 'group-1',
      posts: [
        { id: 'post-1', parentPostId: null },
        { id: 'post-2', parentPostId: 'post-1' },
      ],
    });

    const result = await controller.reschedule(org as any, 'group-1', {
      date: '2026-01-02',
    } as any);

    expect(postsService.changeDate).toHaveBeenCalledTimes(1);
    expect(postsService.changeDate).toHaveBeenCalledWith(
      'org-1',
      'post-1',
      '2026-01-02',
      'update',
      false
    );
    expect(result).toEqual({ group: 'group-1', date: '2026-01-02' });
  });

  it('reschedule throws 404 when the group has no posts', async () => {
    const { controller, postsService } = makeController();
    postsService.getPostsByGroup.mockResolvedValue({ posts: [] });

    await expect(
      controller.reschedule(org as any, 'missing', { date: '2026-01-02' } as any)
    ).rejects.toMatchObject({
      status: 404,
      response: { msg: 'Post not found' },
    });
  });

  it('remove deletes the group and returns ok', async () => {
    const { controller, postsService } = makeController();

    const result = await controller.remove(org as any, 'group-1');

    expect(postsService.deletePost).toHaveBeenCalledWith('org-1', 'group-1');
    expect(result).toEqual({ ok: true });
  });
});
