import 'reflect-metadata';

// mobile.module.ts pulls in ApiModule and MobileAuthController, both of which
// transitively import the real AuthService, which pulls in nostr-tools (ESM)
// that ts-jest's CJS transform cannot require — see
// mobile-auth.controller.spec.ts for the same workaround, applied here to
// every real import MobileModule reaches since only the class reference is
// needed. (reused from mobile-devices.controller.spec.ts:9-27)
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
jest.mock(
  '@gitroom/backend/services/auth/permissions/permissions.service',
  () => ({ PermissionsService: class PermissionsService {} })
);
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/posts/posts.service',
  () => ({ PostsService: class PostsService {} })
);

import { MobilePushController } from '@gitroom/backend/api/routes/mobile/mobile-push.controller';
import { MobileModule } from '@gitroom/backend/api/routes/mobile/mobile.module';

describe('MobilePushController', () => {
  const user = { id: 'user-1' };
  const org = { id: 'org-1' };

  const makeController = () => {
    const pushService = {
      registerDevice: jest.fn().mockResolvedValue({ id: 'device-1' }),
      unregisterDevice: jest.fn().mockResolvedValue({ ok: true }),
      getPrefs: jest.fn().mockResolvedValue({ prefs: { 'post.published': true } }),
      setPrefs: jest.fn().mockResolvedValue({ ok: true }),
    };

    const controller = new MobilePushController(pushService as any);

    return { controller, pushService };
  };

  it('exposes the /mobile/v1/push path', () => {
    expect(Reflect.getMetadata('path', MobilePushController)).toBe(
      '/mobile/v1/push'
    );
  });

  it('register delegates to pushService and returns { device }', async () => {
    const { controller, pushService } = makeController();
    const body = { apnsToken: 'a'.repeat(64), environment: 'sandbox' };

    const result = await controller.register(user as any, org as any, body as any);

    expect(pushService.registerDevice).toHaveBeenCalledWith(
      user.id,
      org.id,
      body
    );
    expect(result).toEqual({ device: { id: 'device-1' } });
  });

  it('unregister delegates to pushService with (userId, token)', async () => {
    const { controller, pushService } = makeController();

    const result = await controller.unregister(user as any, 'token-1');

    expect(pushService.unregisterDevice).toHaveBeenCalledWith(
      user.id,
      'token-1'
    );
    expect(result).toEqual({ ok: true });
  });

  it('getPrefs delegates to pushService with (userId, token)', async () => {
    const { controller, pushService } = makeController();

    const result = await controller.getPrefs(user as any, {
      token: 'token-1',
    } as any);

    expect(pushService.getPrefs).toHaveBeenCalledWith(user.id, 'token-1');
    expect(result).toEqual({ prefs: { 'post.published': true } });
  });

  it('setPrefs delegates to pushService with (userId, apnsToken, prefs)', async () => {
    const { controller, pushService } = makeController();
    const body = { apnsToken: 'a'.repeat(64), prefs: { 'post.published': false } };

    const result = await controller.setPrefs(user as any, body as any);

    expect(pushService.setPrefs).toHaveBeenCalledWith(
      user.id,
      body.apnsToken,
      body.prefs
    );
    expect(result).toEqual({ ok: true });
  });

  it('MobileModule registers MobilePushController', () => {
    const controllers = Reflect.getMetadata('controllers', MobileModule);
    expect(controllers).toContain(MobilePushController);
  });
});
