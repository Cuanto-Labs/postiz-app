import 'reflect-metadata';

// mobile.module.ts pulls in ApiModule and MobileAuthController, both of which
// transitively import the real AuthService, which pulls in nostr-tools (ESM)
// that ts-jest's CJS transform cannot require — see
// mobile-auth.controller.spec.ts for the same workaround, applied here to
// every real import MobileModule reaches since only the class reference is
// needed.
jest.mock('@gitroom/backend/api/api.module', () => ({
  ApiModule: class ApiModule {},
}));
jest.mock('@gitroom/backend/services/auth/auth.service', () => ({
  AuthService: class AuthService {},
}));
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/integrations/integration.service',
  () => ({ IntegrationService: class IntegrationService {} })
);
jest.mock(
  '@gitroom/nestjs-libraries/integrations/integration.manager',
  () => ({ IntegrationManager: class IntegrationManager {} })
);
jest.mock('@gitroom/nestjs-libraries/redis/redis.service', () => ({
  ioRedis: { set: jest.fn() },
}));

import { MobileTagsController } from '@gitroom/backend/api/routes/mobile/mobile-tags.controller';
import { MobileModule } from '@gitroom/backend/api/routes/mobile/mobile.module';

describe('MobileTagsController', () => {
  const org = { id: 'org-1' };

  const makeController = () => {
    const postsService = {
      getTags: jest.fn(),
      createTag: jest.fn(),
      editTag: jest.fn(),
      deleteTag: jest.fn(),
    };

    const controller = new MobileTagsController(postsService as any);

    return { controller, postsService };
  };

  it('exposes the /mobile/v1/tags path', () => {
    expect(Reflect.getMetadata('path', MobileTagsController)).toBe(
      '/mobile/v1/tags'
    );
  });

  it('getTags delegates to PostsService.getTags', async () => {
    const { controller, postsService } = makeController();
    postsService.getTags.mockResolvedValue([{ id: 'tag-1', name: 'a' }]);

    const result = await controller.getTags(org as any);

    expect(postsService.getTags).toHaveBeenCalledWith(org.id);
    expect(result).toEqual({ tags: [{ id: 'tag-1', name: 'a' }] });
  });

  it('createTag delegates to PostsService.createTag', async () => {
    const { controller, postsService } = makeController();
    const body = { name: 'a', color: '#fff' };
    postsService.createTag.mockResolvedValue({ id: 'tag-1', ...body });

    const result = await controller.createTag(org as any, body as any);

    expect(postsService.createTag).toHaveBeenCalledWith(org.id, body);
    expect(result).toEqual({ id: 'tag-1', ...body });
  });

  it('editTag delegates to PostsService.editTag', async () => {
    const { controller, postsService } = makeController();
    const body = { name: 'b', color: '#000' };
    postsService.editTag.mockResolvedValue({ id: 'tag-1', ...body });

    const result = await controller.editTag(org as any, body as any, 'tag-1');

    expect(postsService.editTag).toHaveBeenCalledWith('tag-1', org.id, body);
    expect(result).toEqual({ id: 'tag-1', ...body });
  });

  it('deleteTag delegates to PostsService.deleteTag', async () => {
    const { controller, postsService } = makeController();
    postsService.deleteTag.mockResolvedValue({ id: 'tag-1' });

    const result = await controller.deleteTag(org as any, 'tag-1');

    expect(postsService.deleteTag).toHaveBeenCalledWith('tag-1', org.id);
    expect(result).toEqual({ id: 'tag-1' });
  });

  it('MobileModule.prototype.configure exists', () => {
    expect(typeof MobileModule.prototype.configure).toBe('function');
  });
});
