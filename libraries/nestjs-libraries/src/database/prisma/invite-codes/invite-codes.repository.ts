import { Injectable } from '@nestjs/common';
import { PrismaRepository } from '@gitroom/nestjs-libraries/database/prisma/prisma.service';

@Injectable()
export class InviteCodesRepository {
  constructor(private readonly _inviteCode: PrismaRepository<'inviteCode'>) {}

  /**
   * A usable code: exists, active, and not past its expiry. Returned so the
   * caller can bump `timesUsed`; null means "reject this code".
   */
  findUsable(code: string) {
    return this._inviteCode.model.inviteCode.findFirst({
      where: {
        code,
        active: true,
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
    });
  }

  countAll() {
    return this._inviteCode.model.inviteCode.count();
  }

  list() {
    return this._inviteCode.model.inviteCode.findMany({
      orderBy: { createdAt: 'desc' },
    });
  }

  create(data: { code: string; label?: string; expiresAt?: Date | null }) {
    return this._inviteCode.model.inviteCode.create({
      data: {
        code: data.code,
        label: data.label,
        expiresAt: data.expiresAt ?? null,
      },
    });
  }

  update(
    id: string,
    data: { label?: string; active?: boolean; expiresAt?: Date | null }
  ) {
    return this._inviteCode.model.inviteCode.update({
      where: { id },
      data,
    });
  }

  delete(id: string) {
    return this._inviteCode.model.inviteCode.delete({ where: { id } });
  }

  markUsed(id: string) {
    return this._inviteCode.model.inviteCode.update({
      where: { id },
      data: { timesUsed: { increment: 1 } },
    });
  }

  /** Idempotent seed — used to migrate the env allow-list into the table. */
  upsertSeed(code: string, label: string) {
    return this._inviteCode.model.inviteCode.upsert({
      where: { code },
      update: {},
      create: { code, label },
    });
  }
}
