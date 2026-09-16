import { randomUUID } from 'crypto';
import {
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthService as AuthChecker } from '@gitroom/helpers/auth/auth.service';
import type { UsersService } from '@gitroom/nestjs-libraries/database/prisma/users/users.service';
import type { OrganizationService } from '@gitroom/nestjs-libraries/database/prisma/organizations/organization.service';
import { MobileSessionRepository } from '@gitroom/nestjs-libraries/mobile/mobile-session.repository';
import { MobileTokenService } from '@gitroom/nestjs-libraries/mobile/mobile-token.service';

export type MobileDevice = {
  deviceId: string;
  deviceName?: string;
  platform?: string;
};

export type MobileTokens = {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  sessionId: string;
};

export type MobileAuthResponse = MobileTokens & {
  user: {
    id: string;
    email: string;
    name?: string;
    lastName?: string;
    pictureId?: string;
  };
  orgs: Array<{ id: string; name: string; role: string; disabled: boolean }>;
};

@Injectable()
export class MobileAuthService {
  constructor(
    private _mobileSessionRepository: MobileSessionRepository,
    private _mobileTokenService: MobileTokenService,
    private _usersService: UsersService,
    private _organizationService: OrganizationService
  ) {}

  async issueSession(
    userId: string,
    device: MobileDevice,
    familyId: string = randomUUID()
  ): Promise<MobileTokens> {
    const refreshToken = this._mobileTokenService.generateRefreshToken();
    const refreshTokenHash =
      this._mobileTokenService.hashRefreshToken(refreshToken);
    const expiresAt = this._mobileTokenService.refreshExpiry();

    const session = await this._mobileSessionRepository.create({
      userId,
      familyId,
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      platform: device.platform,
      refreshTokenHash,
      expiresAt,
    });

    const accessToken = this._mobileTokenService.signAccessToken({
      userId,
      sessionId: session.id,
    });

    return {
      accessToken,
      refreshToken,
      expiresIn: 900,
      sessionId: session.id,
    };
  }

  async buildResponse(
    user: { id: string; email: string; name?: string; lastName?: string; pictureId?: string; password?: string },
    tokens: MobileTokens
  ): Promise<MobileAuthResponse> {
    const { password: _password, ...safeUser } = user;
    const allOrgs = await this._organizationService.getOrgsByUserId(user.id);
    const orgs = allOrgs
      .filter((o: any) => !o.users[0].disabled)
      .map((o: any) => ({
        id: o.id,
        name: o.name,
        role: o.users[0].role,
        disabled: o.users[0].disabled,
      }));

    return {
      ...tokens,
      user: safeUser,
      orgs,
    };
  }

  async completeLogin(
    user: { id: string; email: string; name?: string; lastName?: string; pictureId?: string; password?: string },
    device: MobileDevice
  ): Promise<MobileAuthResponse> {
    const tokens = await this.issueSession(user.id, device);
    return this.buildResponse(user, tokens);
  }

  async completeLoginByEmail(
    email: string,
    device: MobileDevice
  ): Promise<MobileAuthResponse> {
    const user = await this._usersService.getUserByEmail(email);
    return this.completeLogin(user as any, device);
  }

  async loginEmail(
    email: string,
    password: string,
    device: MobileDevice
  ): Promise<MobileAuthResponse> {
    const user = await this._usersService.getUserByEmail(email.toLowerCase());
    if (!user || !AuthChecker.comparePassword(password, user.password!)) {
      throw new UnauthorizedException('Invalid user name or password');
    }

    if (!user.activated) {
      throw new ForbiddenException('User is not activated');
    }

    return this.completeLogin(user as any, device);
  }

  async refresh(
    refreshToken: string,
    device?: MobileDevice
  ): Promise<MobileTokens> {
    const hash = this._mobileTokenService.hashRefreshToken(refreshToken);
    const session = await this._mobileSessionRepository.findByRefreshHash(
      hash
    );

    if (!session) {
      const prev = await this._mobileSessionRepository.findByPreviousHash(
        hash
      );
      if (prev) {
        await this._mobileSessionRepository.revokeFamily(prev.familyId);
        throw new UnauthorizedException('Refresh token reuse detected');
      }
      throw new UnauthorizedException('Invalid refresh token');
    }

    if (session.revokedAt) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    if (session.expiresAt < new Date()) {
      await this._mobileSessionRepository.revoke(session.id);
      throw new UnauthorizedException('Invalid refresh token');
    }

    const newRefreshToken = this._mobileTokenService.generateRefreshToken();
    const newHash = this._mobileTokenService.hashRefreshToken(
      newRefreshToken
    );
    const newExpiresAt = this._mobileTokenService.refreshExpiry();

    await this._mobileSessionRepository.rotate(
      session.id,
      hash,
      newHash,
      newExpiresAt
    );

    const accessToken = this._mobileTokenService.signAccessToken({
      userId: session.userId,
      sessionId: session.id,
    });

    return {
      accessToken,
      refreshToken: newRefreshToken,
      expiresIn: 900,
      sessionId: session.id,
    };
  }

  async logout(refreshToken: string): Promise<void> {
    const hash = this._mobileTokenService.hashRefreshToken(refreshToken);
    const session = await this._mobileSessionRepository.findByRefreshHash(
      hash
    );
    if (!session) {
      return;
    }
    await this._mobileSessionRepository.revoke(session.id);
  }

  async logoutSession(sessionId: string): Promise<void> {
    await this._mobileSessionRepository.revoke(sessionId);
  }

  async listDevices(userId: string, currentSessionId?: string) {
    const sessions = await this._mobileSessionRepository.listActiveForUser(
      userId
    );
    return sessions.map((session: any) => ({
      ...session,
      current: session.id === currentSessionId,
    }));
  }

  async revokeDevice(userId: string, sessionId: string): Promise<void> {
    const session = await this._mobileSessionRepository.findById(sessionId);
    if (!session || session.userId !== userId) {
      throw new NotFoundException('Session not found');
    }
    await this._mobileSessionRepository.revoke(sessionId);
  }
}
