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
// MobilePlugsController imports these directly (not via ApiModule), and
// IntegrationManager transitively reaches nostr.provider.ts -> nostr-tools,
// an ESM package ts-jest's CJS transform cannot require. Only the class
// references are needed here, so stub them the same way.
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

import { MobilePlugsController } from '@gitroom/backend/api/routes/mobile/mobile-plugs.controller';
import { MobileModule } from '@gitroom/backend/api/routes/mobile/mobile.module';

describe('MobilePlugsController', () => {
  const org = { id: 'org-1' };

  const makeController = () => {
    const integrationService = {
      getPlugsByIntegrationId: jest.fn(),
      createOrUpdatePlug: jest.fn(),
      changePlugActivation: jest.fn(),
    };
    const integrationManager = {
      getAllPlugs: jest.fn(),
    };

    const controller = new MobilePlugsController(
      integrationService as any,
      integrationManager as any
    );

    return { controller, integrationService, integrationManager };
  };

  it('exposes the /mobile/v1/plugs path', () => {
    expect(Reflect.getMetadata('path', MobilePlugsController)).toBe(
      '/mobile/v1/plugs'
    );
  });

  it('list returns the plug catalogue from IntegrationManager.getAllPlugs()', async () => {
    const { controller, integrationManager } = makeController();
    integrationManager.getAllPlugs.mockReturnValue([{ name: 'plug-1' }]);

    const result = await controller.list();

    expect(integrationManager.getAllPlugs).toHaveBeenCalled();
    expect(result).toEqual({ plugs: [{ name: 'plug-1' }] });
  });

  it('getByChannel delegates to IntegrationService.getPlugsByIntegrationId(org.id, id)', async () => {
    const { controller, integrationService } = makeController();
    integrationService.getPlugsByIntegrationId.mockResolvedValue([
      { id: 'plug-1' },
    ]);

    const result = await controller.getByChannel('int-1', org as any);

    expect(integrationService.getPlugsByIntegrationId).toHaveBeenCalledWith(
      org.id,
      'int-1'
    );
    expect(result).toEqual([{ id: 'plug-1' }]);
  });

  it('createOrUpdate delegates to IntegrationService.createOrUpdatePlug(org.id, id, body)', async () => {
    const { controller, integrationService } = makeController();
    const body = { func: 'my-func', fields: [{ name: 'a', value: 'b' }] };
    integrationService.createOrUpdatePlug.mockResolvedValue({ id: 'plug-1' });

    const result = await controller.createOrUpdate(
      'int-1',
      org as any,
      body as any
    );

    expect(integrationService.createOrUpdatePlug).toHaveBeenCalledWith(
      org.id,
      'int-1',
      body
    );
    expect(result).toEqual({ id: 'plug-1' });
  });

  it('activate delegates to IntegrationService.changePlugActivation(org.id, id, status)', async () => {
    const { controller, integrationService } = makeController();
    integrationService.changePlugActivation.mockResolvedValue({
      id: 'plug-1',
      activated: true,
    });

    const result = await controller.activate('plug-1', org as any, {
      status: true,
    });

    expect(integrationService.changePlugActivation).toHaveBeenCalledWith(
      org.id,
      'plug-1',
      true
    );
    expect(result).toEqual({ id: 'plug-1', activated: true });
  });

  it('MobileModule.prototype.configure exists', () => {
    expect(typeof MobileModule.prototype.configure).toBe('function');
  });
});
