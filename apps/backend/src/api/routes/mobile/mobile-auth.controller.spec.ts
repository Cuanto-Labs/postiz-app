import 'reflect-metadata';

// The real AuthService transitively pulls in nostr-tools, which ships ESM and
// cannot be required under ts-jest's CJS transform. The controller only needs
// the class reference for Nest's design:paramtypes metadata; every method is
// mocked below, so a lightweight stand-in avoids the ESM import entirely.
jest.mock('@gitroom/backend/services/auth/auth.service', () => ({
  AuthService: class AuthService {},
}));

import { MobileAuthController } from '@gitroom/backend/api/routes/mobile/mobile-auth.controller';

describe('MobileAuthController', () => {
  const device = { deviceId: 'device-1', deviceName: 'iPhone' };

  const makeController = (overrides: {
    canRegister?: boolean;
    hasProvider?: boolean;
    isAcceptable?: boolean;
  } = {}) => {
    const mobileAuthService = {
      loginEmail: jest.fn().mockResolvedValue({ accessToken: 'a' }),
      completeLoginByEmail: jest.fn().mockResolvedValue({ accessToken: 'b' }),
      refresh: jest.fn().mockResolvedValue({ accessToken: 'c' }),
      logout: jest.fn().mockResolvedValue(undefined),
    };
    const authService = {
      canRegister: jest.fn().mockResolvedValue(overrides.canRegister ?? true),
      routeAuth: jest.fn().mockResolvedValue({ jwt: 'jwt', addedOrg: false }),
    };
    const emailService = {
      hasProvider: jest.fn().mockReturnValue(overrides.hasProvider ?? false),
    };
    const inviteCodesService = {
      isAcceptable: jest
        .fn()
        .mockResolvedValue(overrides.isAcceptable ?? true),
    };
    const mobileOAuthService = {};

    const controller = new MobileAuthController(
      mobileAuthService as any,
      authService as any,
      emailService as any,
      inviteCodesService as any,
      mobileOAuthService as any
    );

    return {
      controller,
      mobileAuthService,
      authService,
      emailService,
      inviteCodesService,
      mobileOAuthService,
    };
  };

  it('exposes the /mobile/v1/auth path', () => {
    expect(Reflect.getMetadata('path', MobileAuthController)).toBe(
      '/mobile/v1/auth'
    );
  });

  it('login delegates to mobileAuthService with device', async () => {
    const { controller, mobileAuthService } = makeController();
    const body = { email: 'a@b.com', password: 'password', ...device };

    await controller.login(body as any, '1.2.3.4', 'ua');

    expect(mobileAuthService.loginEmail).toHaveBeenCalledWith(
      body.email,
      body.password,
      { deviceId: device.deviceId, deviceName: device.deviceName }
    );
  });

  it('register returns { activate: true } when emailService.hasProvider() is true', async () => {
    const { controller, authService } = makeController({ hasProvider: true });
    const body = {
      email: 'a@b.com',
      password: 'password',
      ...device,
    };

    const result = await controller.register(body as any, '1.2.3.4', 'ua');

    expect(result).toEqual({ activate: true });
    expect(authService.routeAuth).toHaveBeenCalled();
  });

  it('register rejects a bad invite code', async () => {
    const { controller } = makeController({ isAcceptable: false });
    const body = {
      email: 'a@b.com',
      password: 'password',
      inviteCode: 'BAD',
      ...device,
    };

    await expect(
      controller.register(body as any, '1.2.3.4', 'ua')
    ).rejects.toThrow('Invalid invite code');
  });

  it('refresh delegates to mobileAuthService', async () => {
    const { controller, mobileAuthService } = makeController();
    const body = { refreshToken: 'r'.repeat(32) };

    const result = await controller.refresh(body as any);

    expect(mobileAuthService.refresh).toHaveBeenCalledWith(body.refreshToken);
    expect(result).toEqual({ accessToken: 'c' });
  });

  it('logout returns { ok: true }', async () => {
    const { controller, mobileAuthService } = makeController();
    const body = { refreshToken: 'r' };

    const result = await controller.logout(body as any);

    expect(mobileAuthService.logout).toHaveBeenCalledWith(body.refreshToken);
    expect(result).toEqual({ ok: true });
  });
});
