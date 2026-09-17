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

import { MobileSetsController } from '@gitroom/backend/api/routes/mobile/mobile-sets.controller';
import { MobileModule } from '@gitroom/backend/api/routes/mobile/mobile.module';

describe('MobileSetsController', () => {
  const org = { id: 'org-1' };

  const makeController = () => {
    const setsService = {
      getSets: jest.fn(),
      createSet: jest.fn(),
      deleteSet: jest.fn(),
    };

    const controller = new MobileSetsController(setsService as any);

    return { controller, setsService };
  };

  it('exposes the /mobile/v1/sets path', () => {
    expect(Reflect.getMetadata('path', MobileSetsController)).toBe(
      '/mobile/v1/sets'
    );
  });

  it('getSets delegates to SetsService.getSets', async () => {
    const { controller, setsService } = makeController();
    setsService.getSets.mockResolvedValue([{ id: 'set-1', name: 'a' }]);

    const result = await controller.getSets(org as any);

    expect(setsService.getSets).toHaveBeenCalledWith(org.id);
    expect(result).toEqual([{ id: 'set-1', name: 'a' }]);
  });

  it('createSet delegates to SetsService.createSet', async () => {
    const { controller, setsService } = makeController();
    const body = { name: 'a', content: 'x' };
    setsService.createSet.mockResolvedValue({ id: 'set-1', ...body });

    const result = await controller.createSet(org as any, body as any);

    expect(setsService.createSet).toHaveBeenCalledWith(org.id, body);
    expect(result).toEqual({ id: 'set-1', ...body });
  });

  it('updateSet delegates to SetsService.createSet with the id merged in', async () => {
    const { controller, setsService } = makeController();
    const body = { name: 'b', content: 'y' };
    setsService.createSet.mockResolvedValue({ id: 'set-1', ...body });

    const result = await controller.updateSet(
      org as any,
      body as any,
      'set-1'
    );

    expect(setsService.createSet).toHaveBeenCalledWith(org.id, {
      ...body,
      id: 'set-1',
    });
    expect(result).toEqual({ id: 'set-1', ...body });
  });

  it('deleteSet delegates to SetsService.deleteSet', async () => {
    const { controller, setsService } = makeController();
    setsService.deleteSet.mockResolvedValue({ id: 'set-1' });

    const result = await controller.deleteSet(org as any, 'set-1');

    expect(setsService.deleteSet).toHaveBeenCalledWith(org.id, 'set-1');
    expect(result).toEqual({ id: 'set-1' });
  });

  it('MobileModule.prototype.configure exists', () => {
    expect(typeof MobileModule.prototype.configure).toBe('function');
  });
});
