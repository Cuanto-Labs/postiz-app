import {
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { createHash } from 'crypto';
import { Provider, User } from '@prisma/client';
import { AuthService } from '@gitroom/backend/services/auth/auth.service';
import { AuthService as AuthChecker } from '@gitroom/helpers/auth/auth.service';
import { CreateOrgUserDto } from '@gitroom/nestjs-libraries/dtos/auth/create.org.user.dto';
import {
  MobileAuthService,
  MobileAuthResponse,
} from '@gitroom/nestjs-libraries/mobile/mobile-auth.service';
import { MobileTokenService } from '@gitroom/nestjs-libraries/mobile/mobile-token.service';

interface GoogleOAuthState {
  provider: 'google';
  cc: string;
}

@Injectable()
export class MobileOAuthService {
  googleTokenUrl = 'https://oauth2.googleapis.com/token';

  constructor(
    private _authService: AuthService,
    private _mobileAuthService: MobileAuthService,
    private _mobileTokenService: MobileTokenService
  ) {}

  async appleNative(
    dto: {
      identityToken: string;
      deviceId: string;
      deviceName?: string;
      fullName?: string;
    },
    ip: string,
    ua: string
  ): Promise<MobileAuthResponse> {
    const body = Object.assign(new CreateOrgUserDto(), {
      provider: 'APPLE',
      providerToken: dto.identityToken,
      company: dto.fullName || 'Personal',
      email: '',
      password: '',
    });

    let jwt: string;
    try {
      ({ jwt } = await this._authService.routeAuth(
        'APPLE' as Provider,
        body,
        ip,
        ua
      ));
    } catch (e: any) {
      throw new UnauthorizedException(e.message);
    }

    const user = AuthChecker.verifyJWT(jwt) as User;

    return this._mobileAuthService.completeLogin(user as any, {
      deviceId: dto.deviceId,
      deviceName: dto.deviceName,
      platform: 'ios',
    });
  }

  googleStart(codeChallenge: string): { url: string; state: string } {
    const clientId = process.env.MOBILE_GOOGLE_CLIENT_ID;
    if (!clientId) {
      throw new ServiceUnavailableException('Google sign-in not configured');
    }

    const state = this._mobileTokenService.signStateToken(
      { provider: 'google', cc: codeChallenge },
      600
    );

    const params = new URLSearchParams({
      client_id: clientId,
      redirect_uri:
        process.env.MOBILE_OAUTH_REDIRECT_URI ||
        'https://socials.cuantolabs.com/m/auth/callback',
      response_type: 'code',
      scope: 'openid email profile',
      code_challenge: codeChallenge,
      code_challenge_method: 'S256',
      state,
      access_type: 'online',
    });

    return {
      url: `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`,
      state,
    };
  }

  async googleExchange(
    dto: {
      code: string;
      state: string;
      codeVerifier: string;
      deviceId: string;
      deviceName?: string;
    },
    ip: string,
    ua: string
  ): Promise<MobileAuthResponse> {
    let payload: GoogleOAuthState;
    try {
      payload = this._mobileTokenService.verifyStateToken<GoogleOAuthState>(
        dto.state
      );
    } catch (e: any) {
      throw new UnauthorizedException('Invalid state');
    }

    if (
      payload.provider !== 'google' ||
      createHash('sha256').update(dto.codeVerifier).digest('base64url') !==
        payload.cc
    ) {
      throw new UnauthorizedException('PKCE verification failed');
    }

    const clientId = process.env.MOBILE_GOOGLE_CLIENT_ID;
    const clientSecret = process.env.MOBILE_GOOGLE_CLIENT_SECRET;
    const redirectUri =
      process.env.MOBILE_OAUTH_REDIRECT_URI ||
      'https://socials.cuantolabs.com/m/auth/callback';

    const response = await fetch(this.googleTokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
      },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code: dto.code,
        client_id: clientId!,
        redirect_uri: redirectUri,
        code_verifier: dto.codeVerifier,
        ...(clientSecret ? { client_secret: clientSecret } : {}),
      }),
    });

    const json = response.ok ? await response.json() : undefined;
    if (!response.ok || !json?.access_token) {
      throw new UnauthorizedException('Google token exchange failed');
    }

    const body = Object.assign(new CreateOrgUserDto(), {
      provider: 'GOOGLE',
      providerToken: json.access_token,
      company: 'Personal',
      email: '',
      password: '',
    });

    let jwt: string;
    try {
      ({ jwt } = await this._authService.routeAuth(
        'GOOGLE' as Provider,
        body,
        ip,
        ua
      ));
    } catch (e: any) {
      throw new UnauthorizedException(e.message);
    }

    const user = AuthChecker.verifyJWT(jwt) as User;

    return this._mobileAuthService.completeLogin(user as any, {
      deviceId: dto.deviceId,
      deviceName: dto.deviceName,
      platform: 'ios',
    });
  }
}
