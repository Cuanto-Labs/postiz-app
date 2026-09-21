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

import { MobileAnalyticsController } from '@gitroom/backend/api/routes/mobile/mobile-analytics.controller';
import { MobileModule } from '@gitroom/backend/api/routes/mobile/mobile.module';

describe('MobileAnalyticsController', () => {
  const org = { id: 'org-1' };

  const makeController = () => {
    const integrationService = {
      checkAnalytics: jest.fn(),
    };
    const postsService = {
      checkPostAnalytics: jest.fn(),
    };

    const controller = new MobileAnalyticsController(
      integrationService as any,
      postsService as any
    );

    return { controller, integrationService, postsService };
  };

  it('exposes the /mobile/v1/analytics path', () => {
    expect(Reflect.getMetadata('path', MobileAnalyticsController)).toBe(
      '/mobile/v1/analytics'
    );
  });

  it('getIntegration delegates to IntegrationService.checkAnalytics(org, integration, date)', async () => {
    const { controller, integrationService } = makeController();
    integrationService.checkAnalytics.mockResolvedValue({ ok: true });

    const result = await controller.getIntegration(org as any, 'int-1', {
      date: '7',
    } as any);

    expect(integrationService.checkAnalytics).toHaveBeenCalledWith(
      org,
      'int-1',
      '7'
    );
    expect(result).toEqual({ ok: true });
  });

  it('getPostAnalytics delegates to PostsService.checkPostAnalytics(org.id, postId, +date)', async () => {
    const { controller, postsService } = makeController();
    postsService.checkPostAnalytics.mockResolvedValue({ ok: true });

    const result = await controller.getPostAnalytics(org as any, 'post-1', {
      date: '7',
    } as any);

    expect(postsService.checkPostAnalytics).toHaveBeenCalledWith(
      org.id,
      'post-1',
      7
    );
    expect(result).toEqual({ ok: true });
  });

  it('MobileModule.prototype.configure exists', () => {
    expect(typeof MobileModule.prototype.configure).toBe('function');
  });
});
