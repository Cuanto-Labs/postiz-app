import { Injectable } from '@nestjs/common';
import { PrismaRepository } from '@gitroom/nestjs-libraries/database/prisma/prisma.service';

@Injectable()
export class PushDeviceRepository {
  constructor(private _pushDevice: PrismaRepository<'pushDevice'>) {}

  upsertByToken(data: {
    userId: string;
    organizationId?: string;
    apnsToken: string;
    environment: string;
    bundleId: string;
    locale?: string;
    timezone?: string;
    prefs?: any;
  }) {
    const {
      userId,
      organizationId,
      apnsToken,
      environment,
      bundleId,
      locale,
      timezone,
      prefs,
    } = data;
    return this._pushDevice.model.pushDevice.upsert({
      where: { apnsToken },
      create: {
        userId,
        organizationId,
        apnsToken,
        environment,
        bundleId,
        locale,
        timezone,
        ...(prefs !== undefined ? { prefs } : {}),
      },
      update: {
        userId,
        organizationId,
        environment,
        bundleId,
        locale,
        timezone,
        ...(prefs !== undefined ? { prefs } : {}),
        lastSeenAt: new Date(),
        disabledAt: null,
      },
    });
  }

  findByToken(userId: string, apnsToken: string) {
    return this._pushDevice.model.pushDevice.findFirst({
      where: { userId, apnsToken },
    });
  }

  deleteByToken(userId: string, apnsToken: string) {
    return this._pushDevice.model.pushDevice.deleteMany({
      where: { userId, apnsToken },
    });
  }

  updatePrefs(userId: string, apnsToken: string, prefs: any) {
    return this._pushDevice.model.pushDevice.updateMany({
      where: { userId, apnsToken },
      data: { prefs },
    });
  }

  disableByToken(apnsToken: string) {
    return this._pushDevice.model.pushDevice.updateMany({
      where: { apnsToken },
      data: { disabledAt: new Date() },
    });
  }

  listActiveForUsers(userIds: string[]) {
    return this._pushDevice.model.pushDevice.findMany({
      where: {
        userId: { in: userIds },
        disabledAt: null,
      },
    });
  }

  deleteAllForUser(userId: string) {
    return this._pushDevice.model.pushDevice.deleteMany({
      where: { userId },
    });
  }
}
