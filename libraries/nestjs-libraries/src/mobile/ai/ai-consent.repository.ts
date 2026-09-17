import { Injectable } from '@nestjs/common';
import { PrismaRepository } from '@gitroom/nestjs-libraries/database/prisma/prisma.service';

@Injectable()
export class AiConsentRepository {
  constructor(private _user: PrismaRepository<'user'>) {}

  getConsentAt(userId: string) {
    return this._user.model.user
      .findUnique({
        where: { id: userId },
        select: { aiConsentAt: true },
      })
      .then((user) => user?.aiConsentAt ?? null);
  }

  setConsent(userId: string, granted: boolean) {
    return this._user.model.user.update({
      where: { id: userId },
      data: { aiConsentAt: granted ? new Date() : null },
    });
  }
}
