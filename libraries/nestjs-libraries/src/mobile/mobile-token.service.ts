import { Injectable } from '@nestjs/common';
import { sign, verify } from 'jsonwebtoken';
import crypto from 'crypto';

export const ACCESS_TTL_SECONDS = 900;
export const REFRESH_TTL_DAYS = 60;
export const MOBILE_AUD = 'mobile';
export const MOBILE_ISS = 'cuanto-socials';

const MOBILE_OAUTH_AUD = 'mobile-oauth';

@Injectable()
export class MobileTokenService {
  signAccessToken(input: { userId: string; sessionId: string }): string {
    return sign(
      { sub: input.userId, sid: input.sessionId },
      process.env.JWT_SECRET!,
      {
        algorithm: 'HS256',
        audience: MOBILE_AUD,
        issuer: MOBILE_ISS,
        expiresIn: ACCESS_TTL_SECONDS,
      }
    );
  }

  verifyAccessToken(token: string): { userId: string; sessionId: string } {
    const payload = verify(token, process.env.JWT_SECRET!, {
      algorithms: ['HS256'],
      audience: MOBILE_AUD,
      issuer: MOBILE_ISS,
    }) as { sub: string; sid: string };

    return { userId: payload.sub, sessionId: payload.sid };
  }

  generateRefreshToken(): string {
    return crypto.randomBytes(48).toString('base64url');
  }

  hashRefreshToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  refreshExpiry(now: Date = new Date()): Date {
    return new Date(now.getTime() + REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000);
  }

  signStateToken(payload: Record<string, unknown>, ttlSeconds = 600): string {
    return sign(payload, process.env.JWT_SECRET!, {
      algorithm: 'HS256',
      audience: MOBILE_OAUTH_AUD,
      issuer: MOBILE_ISS,
      expiresIn: ttlSeconds,
    });
  }

  verifyStateToken<T>(token: string): T {
    return verify(token, process.env.JWT_SECRET!, {
      algorithms: ['HS256'],
      audience: MOBILE_OAUTH_AUD,
      issuer: MOBILE_ISS,
    }) as T;
  }
}
