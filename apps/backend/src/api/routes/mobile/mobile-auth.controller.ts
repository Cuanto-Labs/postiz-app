import { BadRequestException, Body, Controller, ForbiddenException, Post, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiTags } from '@nestjs/swagger';
import { RealIP } from 'nestjs-real-ip';
import { Provider } from '@prisma/client';
import { ThrottlerRealIpGuard } from '@gitroom/nestjs-libraries/throttler/throttler.provider';
import { UserAgent } from '@gitroom/nestjs-libraries/user/user.agent';
import { AuthService } from '@gitroom/backend/services/auth/auth.service';
import { EmailService } from '@gitroom/nestjs-libraries/services/email.service';
import { InviteCodesService } from '@gitroom/nestjs-libraries/database/prisma/invite-codes/invite-codes.service';
import { MobileAuthService } from '@gitroom/nestjs-libraries/mobile/mobile-auth.service';
import { MobileOAuthService } from '@gitroom/backend/api/routes/mobile/mobile-oauth.service';
import {
  MobileAppleNativeDto,
  MobileLoginDto,
  MobileLogoutDto,
  MobileOAuthExchangeDto,
  MobileOAuthStartDto,
  MobileRefreshDto,
  MobileRegisterDto,
} from '@gitroom/nestjs-libraries/dtos/mobile/mobile-auth.dto';

@ApiTags('Mobile Auth')
@Controller('/mobile/v1/auth')
export class MobileAuthController {
  constructor(
    private _mobileAuthService: MobileAuthService,
    private _authService: AuthService,
    private _emailService: EmailService,
    private _inviteCodesService: InviteCodesService,
    private _mobileOAuthService: MobileOAuthService
  ) {}

  @Post('/login')
  @UseGuards(ThrottlerRealIpGuard)
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async login(
    @Body() body: MobileLoginDto,
    @RealIP() ip: string,
    @UserAgent() userAgent: string
  ) {
    return this._mobileAuthService.loginEmail(body.email, body.password, {
      deviceId: body.deviceId,
      deviceName: body.deviceName,
    });
  }

  @Post('/register')
  @UseGuards(ThrottlerRealIpGuard)
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async register(
    @Body() body: MobileRegisterDto,
    @RealIP() ip: string,
    @UserAgent() userAgent: string
  ) {
    if (!(await this._authService.canRegister('LOCAL'))) {
      throw new ForbiddenException('Registration is disabled');
    }

    if (
      body.inviteCode &&
      !(await this._inviteCodesService.isAcceptable(body.inviteCode))
    ) {
      throw new ForbiddenException('Invalid invite code');
    }

    body.provider = Provider.LOCAL;

    try {
      await this._authService.routeAuth(Provider.LOCAL, body, ip, userAgent);
    } catch (e: any) {
      throw new BadRequestException(e.message);
    }

    if (this._emailService.hasProvider()) {
      return { activate: true };
    }

    return this._mobileAuthService.completeLoginByEmail(body.email, {
      deviceId: body.deviceId,
      deviceName: body.deviceName,
    });
  }

  @Post('apple/native')
  @UseGuards(ThrottlerRealIpGuard)
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async appleNative(
    @Body() body: MobileAppleNativeDto,
    @RealIP() ip: string,
    @UserAgent() userAgent: string
  ) {
    return this._mobileOAuthService.appleNative(body, ip, userAgent);
  }

  @Post('oauth/start')
  @UseGuards(ThrottlerRealIpGuard)
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async oauthStart(@Body() body: MobileOAuthStartDto) {
    return this._mobileOAuthService.googleStart(body.codeChallenge);
  }

  @Post('oauth/exchange')
  @UseGuards(ThrottlerRealIpGuard)
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async oauthExchange(
    @Body() body: MobileOAuthExchangeDto,
    @RealIP() ip: string,
    @UserAgent() userAgent: string
  ) {
    return this._mobileOAuthService.googleExchange(body, ip, userAgent);
  }

  @Post('/refresh')
  @UseGuards(ThrottlerRealIpGuard)
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async refresh(@Body() body: MobileRefreshDto) {
    return this._mobileAuthService.refresh(body.refreshToken);
  }

  @Post('/logout')
  @UseGuards(ThrottlerRealIpGuard)
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async logout(@Body() body: MobileLogoutDto) {
    await this._mobileAuthService.logout(body.refreshToken);
    return { ok: true };
  }
}
