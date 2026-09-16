import { Injectable, UnauthorizedException } from '@nestjs/common';
import { Provider, User } from '@prisma/client';
import { AuthService } from '@gitroom/backend/services/auth/auth.service';
import { AuthService as AuthChecker } from '@gitroom/helpers/auth/auth.service';
import { CreateOrgUserDto } from '@gitroom/nestjs-libraries/dtos/auth/create.org.user.dto';
import {
  MobileAuthService,
  MobileAuthResponse,
} from '@gitroom/nestjs-libraries/mobile/mobile-auth.service';
import { MobileTokenService } from '@gitroom/nestjs-libraries/mobile/mobile-token.service';

@Injectable()
export class MobileOAuthService {
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
}
