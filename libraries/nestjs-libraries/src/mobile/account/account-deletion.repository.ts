import { Injectable } from '@nestjs/common';
import { PrismaRepository } from '@gitroom/nestjs-libraries/database/prisma/prisma.service';

@Injectable()
export class AccountDeletionRepository {
  constructor(
    private _user: PrismaRepository<'user'>,
    private _userOrganization: PrismaRepository<'userOrganization'>,
    private _post: PrismaRepository<'post'>,
    private _media: PrismaRepository<'media'>,
    private _mobileSession: PrismaRepository<'mobileSession'>,
    private _pushDevice: PrismaRepository<'pushDevice'>,
    private _accountDeletionAudit: PrismaRepository<'accountDeletionAudit'>
  ) {}

  countOtherAdmins(orgId: string, userId: string) {
    return this._userOrganization.model.userOrganization.count({
      where: {
        organizationId: orgId,
        role: 'SUPERADMIN',
        userId: { not: userId },
        disabled: false,
      },
    });
  }

  listRunningPostIds(orgIds: string[]) {
    return this._post.model.post.findMany({
      select: { id: true },
      where: {
        organizationId: { in: orgIds },
        deletedAt: null,
        state: { in: ['QUEUE'] },
      },
    });
  }

  listProcessingMediaIds(orgIds: string[]) {
    return this._media.model.media.findMany({
      select: { id: true },
      where: {
        organizationId: { in: orgIds },
        status: 'processing',
      },
    });
  }

  softDeleteMedia(orgId: string) {
    return this._media.model.media.updateMany({
      where: { organizationId: orgId },
      data: { deletedAt: new Date() },
    });
  }

  async revokeUserSessions(userId: string) {
    const sessions = await this._mobileSession.model.mobileSession.deleteMany(
      {
        where: { userId },
      }
    );
    const devices = await this._pushDevice.model.pushDevice.deleteMany({
      where: { userId },
    });
    return { sessions: sessions.count, devices: devices.count };
  }

  anonymizeUser(userId: string, hash: string) {
    return this._user.model.user.update({
      where: { id: userId },
      data: {
        email: `deleted+${hash}@deleted.invalid`,
        name: null,
        lastName: null,
        pictureId: null,
        password: null,
        providerId: `deleted-${hash}`,
        bio: null,
        activated: false,
        deletedAt: new Date(),
      },
    });
  }

  writeAudit(data: {
    userIdHash: string;
    orgIdsDeleted: string[];
    orgIdsLeft: string[];
    source: string;
  }) {
    return this._accountDeletionAudit.model.accountDeletionAudit.create({
      data: {
        userIdHash: data.userIdHash,
        orgIdsDeleted: data.orgIdsDeleted,
        orgIdsLeft: data.orgIdsLeft,
        source: data.source,
      },
    });
  }
}
