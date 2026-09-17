import { sign } from 'jsonwebtoken';
import { AuthService as AuthChecker } from '@gitroom/helpers/auth/auth.service';
import {
  MobileTokenService,
  MOBILE_AUD,
  MOBILE_ISS,
} from './mobile-token.service';

describe('MobileTokenService', () => {
  let service: MobileTokenService;

  beforeAll(() => {
    process.env.JWT_SECRET = 'test-secret';
  });

  beforeEach(() => {
    service = new MobileTokenService();
  });

  it('round-trips an access token', () => {
    const token = service.signAccessToken({
      userId: 'u1',
      sessionId: 's1',
    });
    const result = service.verifyAccessToken(token);
    expect(result.userId).toBe('u1');
    expect(result.sessionId).toBe('s1');
  });

  it('rejects a web-issued JWT (no aud)', () => {
    const webToken = AuthChecker.signJWT({ id: 'u1' });
    expect(() => service.verifyAccessToken(webToken)).toThrow();
  });

  it('rejects an expired access token', () => {
    const expired = sign(
      { sub: 'u1', sid: 's1' },
      process.env.JWT_SECRET!,
      {
        algorithm: 'HS256',
        audience: MOBILE_AUD,
        issuer: MOBILE_ISS,
        expiresIn: -1,
      }
    );
    expect(() => service.verifyAccessToken(expired)).toThrow();
  });

  it('rejects a state token when verified as an access token, and vice versa', () => {
    const stateToken = service.signStateToken({ foo: 'bar' });
    expect(() => service.verifyAccessToken(stateToken)).toThrow();

    const accessToken = service.signAccessToken({
      userId: 'u1',
      sessionId: 's1',
    });
    expect(() => service.verifyStateToken(accessToken)).toThrow();
  });

  it('generates distinct refresh tokens with a 64-char hex hash', () => {
    const a = service.generateRefreshToken();
    const b = service.generateRefreshToken();
    expect(a).not.toBe(b);
    const hash = service.hashRefreshToken(a);
    expect(hash).toMatch(/^[0-9a-f]{64}$/);
  });
});
