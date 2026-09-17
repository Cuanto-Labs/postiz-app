import { Injectable } from '@nestjs/common';
import { PrismaRepository } from '@gitroom/nestjs-libraries/database/prisma/prisma.service';

@Injectable()
export class MobileSessionRepository {
  constructor(private _mobileSession: PrismaRepository<'mobileSession'>) {}

  create(data: {
    userId: string;
    familyId: string;
    deviceId: string;
    deviceName?: string;
    platform?: string;
    refreshTokenHash: string;
    expiresAt: Date;
  }) {
    return this._mobileSession.model.mobileSession.create({
      data,
    });
  }

  findByRefreshHash(hash: string) {
    return this._mobileSession.model.mobileSession.findFirst({
      where: { refreshTokenHash: hash },
    });
  }

  findByPreviousHash(hash: string) {
    return this._mobileSession.model.mobileSession.findFirst({
      where: { previousTokenHash: hash },
    });
  }

  findById(id: string) {
    return this._mobileSession.model.mobileSession.findFirst({
      where: { id },
    });
  }

  rotate(id: string, oldHash: string, newHash: string, expiresAt: Date) {
    return this._mobileSession.model.mobileSession.update({
      where: { id },
      data: {
        previousTokenHash: oldHash,
        refreshTokenHash: newHash,
        expiresAt,
        lastUsedAt: new Date(),
      },
    });
  }

  touch(id: string) {
    return this._mobileSession.model.mobileSession.update({
      where: { id },
      data: { lastUsedAt: new Date() },
    });
  }

  revoke(id: string) {
    return this._mobileSession.model.mobileSession.update({
      where: { id },
      data: { revokedAt: new Date() },
    });
  }

  revokeFamily(familyId: string) {
    return this._mobileSession.model.mobileSession.updateMany({
      where: { familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  revokeAllForUser(userId: string) {
    return this._mobileSession.model.mobileSession.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  listActiveForUser(userId: string) {
    return this._mobileSession.model.mobileSession.findMany({
      where: {
        userId,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { lastUsedAt: 'desc' },
      select: {
        id: true,
        deviceId: true,
        deviceName: true,
        platform: true,
        createdAt: true,
        lastUsedAt: true,
      },
    });
  }
}
