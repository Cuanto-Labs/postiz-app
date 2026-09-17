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
      getPostsList: jest.fn(),
      getOldPosts: jest.fn(),
      findFreeDateTime: jest.fn(),
      validatePosts: jest.fn().mockResolvedValue([validRow]),
      mapTypeToPost: jest.fn().mockImplementation((body) => body),
      createPost: jest.fn().mockResolvedValue([{ id: 'post-1' }]),
      deletePost: jest.fn().mockResolvedValue(undefined),
      changeDate: jest.fn().mockResolvedValue(undefined),
      getStatistics: jest.fn(),
      getMissingContent: jest.fn(),
      separatePosts: jest.fn(),
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

  it('declares list/old/find-slot routes before the /:group route', () => {
    const names = Object.getOwnPropertyNames(
      MobilePostsController.prototype
    );
    const idx = (name: string) => names.indexOf(name);

    expect(idx('listPosts')).toBeGreaterThan(-1);
    expect(idx('oldPosts')).toBeGreaterThan(-1);
    expect(idx('findSlot')).toBeGreaterThan(-1);
    expect(idx('findSlotIntegration')).toBeGreaterThan(-1);
    expect(idx('detail')).toBeGreaterThan(-1);

    expect(idx('listPosts')).toBeLessThan(idx('detail'));
    expect(idx('oldPosts')).toBeLessThan(idx('detail'));
    expect(idx('findSlot')).toBeLessThan(idx('detail'));
    expect(idx('findSlotIntegration')).toBeLessThan(idx('detail'));
  });

  it('listPosts delegates to getPostsList', async () => {
    const { controller, postsService } = makeController();
    const listResult = { posts: [{ id: 'post-1' }], total: 1 };
    postsService.getPostsList.mockResolvedValue(listResult);

    const result = await controller.listPosts(org as any, {
      page: 0,
      limit: 20,
    } as any);

    expect(postsService.getPostsList).toHaveBeenCalledWith('org-1', {
      page: 0,
      limit: 20,
    });
    expect(result).toEqual(listResult);
  });

  it('oldPosts delegates to getOldPosts', async () => {
    const { controller, postsService } = makeController();
    postsService.getOldPosts.mockResolvedValue([{ id: 'post-1' }]);

    const result = await controller.oldPosts(org as any, {
      date: '2026-01-01',
    } as any);

    expect(postsService.getOldPosts).toHaveBeenCalledWith(
      'org-1',
      '2026-01-01'
    );
    expect(result).toEqual([{ id: 'post-1' }]);
  });

  it('findSlot delegates to findFreeDateTime', async () => {
    const { controller, postsService } = makeController();
    postsService.findFreeDateTime.mockResolvedValue('2026-01-02T00:00:00Z');

    const result = await controller.findSlot(org as any);

    expect(postsService.findFreeDateTime).toHaveBeenCalledWith('org-1');
    expect(result).toEqual({ date: '2026-01-02T00:00:00Z' });
  });

  it('findSlotIntegration delegates to findFreeDateTime with an id', async () => {
    const { controller, postsService } = makeController();
    postsService.findFreeDateTime.mockResolvedValue('2026-01-02T00:00:00Z');

    const result = await controller.findSlotIntegration(
      org as any,
      'integration-1'
    );

    expect(postsService.findFreeDateTime).toHaveBeenCalledWith(
      'org-1',
      'integration-1'
    );
    expect(result).toEqual({ date: '2026-01-02T00:00:00Z' });
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

  it('getStatistics delegates to PostsService.getStatistics', async () => {
    const { controller, postsService } = makeController();
    const stats = { views: 10 };
    postsService.getStatistics.mockResolvedValue(stats);

    const result = await controller.getStatistics(org as any, 'post-1');

    expect(postsService.getStatistics).toHaveBeenCalledWith('org-1', 'post-1');
    expect(result).toEqual(stats);
  });

  it('getMissingContent delegates to PostsService.getMissingContent', async () => {
    const { controller, postsService } = makeController();
    const missing = { missing: ['title'] };
    postsService.getMissingContent.mockResolvedValue(missing);

    const result = await controller.getMissingContent(org as any, 'post-1');

    expect(postsService.getMissingContent).toHaveBeenCalledWith(
      'org-1',
      'post-1'
    );
    expect(result).toEqual(missing);
  });

  it('separatePosts delegates to PostsService.separatePosts', async () => {
    const { controller, postsService } = makeController();
    const separated = ['part-1', 'part-2'];
    postsService.separatePosts.mockResolvedValue(separated);

    const result = await controller.separatePosts({
      content: 'a very long post',
      len: 10,
    } as any);

    expect(postsService.separatePosts).toHaveBeenCalledWith(
      'a very long post',
      10
    );
    expect(result).toEqual(separated);
  });
});
