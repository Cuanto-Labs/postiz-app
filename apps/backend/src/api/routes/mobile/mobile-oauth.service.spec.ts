import 'reflect-metadata';

// The real AuthService transitively pulls in nostr-tools, which ships ESM and
// cannot be required under ts-jest's CJS transform. This spec only needs the
// class reference for Nest's design:paramtypes metadata; every method is
// mocked below, so a lightweight stand-in avoids the ESM import entirely.
jest.mock('@gitroom/backend/services/auth/auth.service', () => ({
  AuthService: class AuthService {},
}));

process.env.JWT_SECRET = 'test-secret';

import { AuthService as AuthChecker } from '@gitroom/helpers/auth/auth.service';
import { MobileOAuthService } from '@gitroom/backend/api/routes/mobile/mobile-oauth.service';

describe('MobileOAuthService', () => {
  const device = { deviceId: 'device-1', deviceName: 'iPhone' };

  const makeService = () => {
    const authService = {
      routeAuth: jest.fn(),
    };
    const mobileAuthService = {
      completeLogin: jest.fn().mockResolvedValue({ accessToken: 'a' }),
    };
    const mobileTokenService = {};

    const service = new MobileOAuthService(
      authService as any,
      mobileAuthService as any,
      mobileTokenService as any
    );

    return { service, authService, mobileAuthService };
  };

  it('routes through routeAuth and completes login with the decoded user', async () => {
    const { service, authService, mobileAuthService } = makeService();
    const jwt = AuthChecker.signJWT({
      id: 'u1',
      email: 'a@b.c',
      activated: true,
    });
    authService.routeAuth.mockResolvedValue({ jwt, addedOrg: false });

    const result = await service.appleNative(
      { identityToken: 'apple-identity-token-xyz', fullName: 'A B', ...device },
      '1.2.3.4',
      'ua'
    );

    expect(authService.routeAuth).toHaveBeenCalledWith(
      'APPLE',
      expect.objectContaining({ providerToken: 'apple-identity-token-xyz' }),
      '1.2.3.4',
      'ua'
    );
    const [, body] = authService.routeAuth.mock.calls[0];
    expect(body.constructor.name).toBe('CreateOrgUserDto');

    expect(mobileAuthService.completeLogin).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'u1' }),
      { deviceId: device.deviceId, deviceName: device.deviceName, platform: 'ios' }
    );
    expect(result).toEqual({ accessToken: 'a' });
  });

  it('wraps routeAuth failures in UnauthorizedException', async () => {
    const { service, authService } = makeService();
    authService.routeAuth.mockRejectedValue(new Error('Invalid provider token'));

    await expect(
      service.appleNative(
        { identityToken: 'apple-identity-token-xyz', ...device },
        '1.2.3.4',
        'ua'
      )
    ).rejects.toThrow('Invalid provider token');
  });
});
