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

import { MobileDevicesController } from '@gitroom/backend/api/routes/mobile/mobile-devices.controller';
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
});
