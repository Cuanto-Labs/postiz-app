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

describe('MobilePostsController', () => {
  const org = { id: 'org-1' };

  const makeController = () => {
    const postsService = {
      getPostsMinified: jest.fn(),
      getPostsByGroup: jest.fn(),
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
});
