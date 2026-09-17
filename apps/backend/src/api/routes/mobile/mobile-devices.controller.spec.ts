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
// MobileModule now also registers MobileChannelsController, which imports
// IntegrationService/IntegrationManager directly; IntegrationManager
// transitively reaches nostr.provider.ts -> nostr-tools, an ESM package
// ts-jest's CJS transform cannot require. Only the class references are
// needed here, so stub them the same way.
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/integrations/integration.service',
  () => ({ IntegrationService: class IntegrationService {} })
);
jest.mock(
  '@gitroom/nestjs-libraries/integrations/integration.manager',
  () => ({ IntegrationManager: class IntegrationManager {} })
);
// MobileModule also registers MobilePostsController/MobileMeController,
// which pull in PostsService/PermissionsService; PermissionsService in turn
// reaches IntegrationManager -> nostr.provider.ts -> nostr-tools (ESM), same
// issue as above. Only the class reference is needed here.
jest.mock(
  '@gitroom/backend/services/auth/permissions/permissions.service',
  () => ({ PermissionsService: class PermissionsService {} })
);
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/posts/posts.service',
  () => ({ PostsService: class PostsService {} })
);

import { MobileDevicesController } from '@gitroom/backend/api/routes/mobile/mobile-devices.controller';
import { MobileMeController } from '@gitroom/backend/api/routes/mobile/mobile-me.controller';
import { MobileConfigController } from '@gitroom/backend/api/routes/mobile/mobile-config.controller';
import { MobileChannelsController } from '@gitroom/backend/api/routes/mobile/mobile-channels.controller';
import { MobilePostsController } from '@gitroom/backend/api/routes/mobile/mobile-posts.controller';
import { IdempotencyRepository } from '@gitroom/nestjs-libraries/mobile/idempotency.repository';
import { MobileIdempotencyInterceptor } from '@gitroom/backend/api/routes/mobile/mobile-idempotency.interceptor';
import { PermissionsService } from '@gitroom/backend/services/auth/permissions/permissions.service';
import { MobileModule } from '@gitroom/backend/api/routes/mobile/mobile.module';

describe('MobileDevicesController', () => {
  const user = { id: 'user-1' };

  const makeController = () => {
    const mobileAuthService = {
      listDevices: jest.fn().mockResolvedValue([{ id: 'session-1' }]),
      revokeDevice: jest.fn().mockResolvedValue(undefined),
    };

    const controller = new MobileDevicesController(mobileAuthService as any);

    return { controller, mobileAuthService };
  };

  it('exposes the /mobile/v1/devices path', () => {
    expect(Reflect.getMetadata('path', MobileDevicesController)).toBe(
      '/mobile/v1/devices'
    );
  });

  it('list passes the current session id and returns { devices }', async () => {
    const { controller, mobileAuthService } = makeController();
    const req = { mobileSession: { id: 'session-1' } };

    const result = await controller.list(user as any, req as any);

    expect(mobileAuthService.listDevices).toHaveBeenCalledWith(
      user.id,
      'session-1'
    );
    expect(result).toEqual({ devices: [{ id: 'session-1' }] });
  });

  it('revoke delegates to mobileAuthService and returns { ok: true }', async () => {
    const { controller, mobileAuthService } = makeController();

    const result = await controller.revoke(user as any, 'session-1');

    expect(mobileAuthService.revokeDevice).toHaveBeenCalledWith(
      user.id,
      'session-1'
    );
    expect(result).toEqual({ ok: true });
  });

  it('MobileModule.prototype.configure exists', () => {
    expect(typeof MobileModule.prototype.configure).toBe('function');
  });

  it('registers the mobile controllers and idempotency/permissions providers', () => {
    const controllers = Reflect.getMetadata('controllers', MobileModule);
    expect(controllers).toContain(MobileMeController);
    expect(controllers).toContain(MobileConfigController);
    expect(controllers).toContain(MobileChannelsController);
    expect(controllers).toContain(MobilePostsController);

    const providers = Reflect.getMetadata('providers', MobileModule);
    expect(providers).toContain(IdempotencyRepository);
    expect(providers).toContain(MobileIdempotencyInterceptor);
    expect(providers).toContain(PermissionsService);
  });
});
