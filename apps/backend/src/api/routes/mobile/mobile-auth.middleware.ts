import {
  ForbiddenException,
  Injectable,
  NestMiddleware,
  UnauthorizedException,
} from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { MobileTokenService } from '@gitroom/nestjs-libraries/mobile/mobile-token.service';
import { MobileSessionRepository } from '@gitroom/nestjs-libraries/mobile/mobile-session.repository';
import { UsersService } from '@gitroom/nestjs-libraries/database/prisma/users/users.service';
import { OrganizationService } from '@gitroom/nestjs-libraries/database/prisma/organizations/organization.service';

@Injectable()
export class MobileAuthMiddleware implements NestMiddleware {
  constructor(
    private _mobileTokenService: MobileTokenService,
    private _mobileSessionRepository: MobileSessionRepository,
    private _usersService: UsersService,
    private _organizationService: OrganizationService
  ) {}

  async use(req: Request, res: Response, next: NextFunction) {
    const authHeader = req.headers.authorization;
    const match =
      typeof authHeader === 'string'
        ? authHeader.match(/^Bearer\s+(.+)$/i)
        : null;

    if (!match) {
      throw new UnauthorizedException({ msg: 'Missing bearer token' });
    }

    let payload: { userId: string; sessionId: string };
    try {
      payload = this._mobileTokenService.verifyAccessToken(match[1]);
    } catch (err) {
      throw new UnauthorizedException({ msg: 'Invalid token' });
    }

    const session = await this._mobileSessionRepository.findById(
      payload.sessionId
    );

    if (!session || session.revokedAt || session.userId !== payload.userId) {
      throw new UnauthorizedException({ msg: 'Session revoked' });
    }

    const user = await this._usersService.getUserById(payload.userId);

    if (!user || !user.activated) {
      throw new UnauthorizedException({ msg: 'Invalid token' });
    }

    delete user.password;

    const orgs = (
      await this._organizationService.getOrgsByUserId(user.id)
    ).filter((org: any) => !org.users[0].disabled);

    const orgHeader = req.headers.showorg as string | undefined;

    if (orgHeader && !orgs.some((org: any) => org.id === orgHeader)) {
      throw new ForbiddenException({ msg: 'Not a member of this organization' });
    }

    const org =
      (orgHeader && orgs.find((o: any) => o.id === orgHeader)) || orgs[0];

    if (!org) {
      throw new ForbiddenException({ msg: 'No organization' });
    }

    if (!org.apiKey) {
      await this._organizationService.updateApiKey(org.id);
    }

    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-expect-error
    req.user = user;
    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-expect-error
    req.org = org;
    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-expect-error
    req.mobileSession = { id: session.id, familyId: session.familyId };

    Promise.resolve(this._mobileSessionRepository.touch(session.id)).catch(
      () => undefined
    );

    next();
  }
}
