import { Injectable } from '@nestjs/common';
import { PrismaRepository } from '@gitroom/nestjs-libraries/database/prisma/prisma.service';

@Injectable()
export class IdempotencyRepository {
  constructor(private _idempotencyKey: PrismaRepository<'idempotencyKey'>) {}

  find(organizationId: string, key: string) {
    return this._idempotencyKey.model.idempotencyKey.findFirst({
      where: { organizationId, key },
    });
  }

  save(data: {
    organizationId: string;
    key: string;
    method: string;
    path: string;
    requestHash: string;
    statusCode: number;
    response: string;
    expiresAt: Date;
  }) {
    return this._idempotencyKey.model.idempotencyKey.create({
      data,
    });
  }

  purgeExpired(now: Date) {
    return this._idempotencyKey.model.idempotencyKey.deleteMany({
      where: { expiresAt: { lt: now } },
    });
  }
}
