import 'reflect-metadata';

// The real AuthService transitively pulls in nostr-tools, which ships ESM and
// cannot be required under ts-jest's CJS transform. This spec only needs the
// class reference for Nest's design:paramtypes metadata; every method is
// mocked below, so a lightweight stand-in avoids the ESM import entirely.
jest.mock('@gitroom/backend/services/auth/auth.service', () => ({
  AuthService: class AuthService {},
}));

process.env.JWT_SECRET = 'test-secret';
process.env.MOBILE_GOOGLE_CLIENT_ID = 'google-client-id';

import { createHash } from 'crypto';
import { AuthService as AuthChecker } from '@gitroom/helpers/auth/auth.service';
import { MobileTokenService } from '@gitroom/nestjs-libraries/mobile/mobile-token.service';
import { MobileOAuthService } from '@gitroom/backend/api/routes/mobile/mobile-oauth.service';

describe('MobileOAuthService', () => {
  const device = { deviceId: 'device-1', deviceName: 'iPhone' };

  const makeService = (mobileTokenService: any = {}) => {
    const authService = {
      routeAuth: jest.fn(),
    };
    const mobileAuthService = {
      completeLogin: jest.fn().mockResolvedValue({ accessToken: 'a' }),
    };

    const service = new MobileOAuthService(
      authService as any,
      mobileAuthService as any,
      mobileTokenService as any
    );

    return { service, authService, mobileAuthService, mobileTokenService };
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

  describe('Google PKCE', () => {
    const verifier = 'a'.repeat(64);
    const challenge = createHash('sha256')
      .update(verifier)
      .digest('base64url');

    it('googleStart returns an S256 url with a state verifyStateToken accepts', () => {
      const tokenService = new MobileTokenService();
      const { service } = makeService(tokenService);

      const { url, state } = service.googleStart(challenge);

      expect(url).toContain('code_challenge_method=S256');
      expect(
        tokenService.verifyStateToken<{ provider: string; cc: string }>(state)
      ).toEqual(expect.objectContaining({ provider: 'google', cc: challenge }));
    });

    it('googleExchange with wrong verifier returns 401 and does not call fetch', async () => {
      const tokenService = new MobileTokenService();
      const { service } = makeService(tokenService);
      const { state } = service.googleStart(challenge);

      const fetchMock = jest.fn();
      (global as any).fetch = fetchMock;

      await expect(
        service.googleExchange(
          {
            code: 'code',
            state,
            codeVerifier: 'wrong-verifier',
            ...device,
          },
          '1.2.3.4',
          'ua'
        )
      ).rejects.toThrow('PKCE verification failed');

      expect(fetchMock).not.toHaveBeenCalled();
    });

    it('googleExchange with correct verifier routes GOOGLE providerToken through routeAuth', async () => {
      const tokenService = new MobileTokenService();
      const { service, authService } = makeService(tokenService);
      const { state } = service.googleStart(challenge);

      (global as any).fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ access_token: 'ga' }),
      });

      const jwt = AuthChecker.signJWT({
        id: 'u1',
        email: 'a@b.c',
        activated: true,
      });
      authService.routeAuth.mockResolvedValue({ jwt, addedOrg: false });

      await service.googleExchange(
        { code: 'code', state, codeVerifier: verifier, ...device },
        '1.2.3.4',
        'ua'
      );

      expect(authService.routeAuth).toHaveBeenCalledWith(
        'GOOGLE',
        expect.objectContaining({ providerToken: 'ga' }),
        '1.2.3.4',
        'ua'
      );
    });

    it('googleExchange with a tampered state returns 401', async () => {
      const tokenService = new MobileTokenService();
      const { service } = makeService(tokenService);
      const { state } = service.googleStart(challenge);

      await expect(
        service.googleExchange(
          {
            code: 'code',
            state: state.slice(0, -1) + (state.endsWith('a') ? 'b' : 'a'),
            codeVerifier: verifier,
            ...device,
          },
          '1.2.3.4',
          'ua'
        )
      ).rejects.toThrow('Invalid state');
    });
  });
});
