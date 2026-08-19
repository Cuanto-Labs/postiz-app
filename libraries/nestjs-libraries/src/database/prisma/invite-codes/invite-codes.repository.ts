import { Injectable } from '@nestjs/common';
import { PrismaRepository } from '@gitroom/nestjs-libraries/database/prisma/prisma.service';
import { SubscriptionTier } from '@prisma/client';

@Injectable()
export class InviteCodesRepository {
  constructor(private readonly _inviteCode: PrismaRepository<'inviteCode'>) {}

  /**
   * A usable code: exists, active, not past its expiry, and not past maxUses.
   * Returned so the caller can bump `timesUsed`; null means "reject this code".
   *
   * maxUses is compared in the query rather than in the caller so signup and
   * redemption can never disagree about whether a code is spent.
   */
  async findUsable(code: string) {
    const found = await this._inviteCode.model.inviteCode.findFirst({
      where: {
        code,
        active: true,
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
    });

    // maxUses is compared here rather than with a Prisma field reference:
    // maxUses is Int? and timesUsed is Int, and cross-nullability field refs
    // are rejected at runtime.
    if (found?.maxUses != null && found.timesUsed >= found.maxUses) {
      return null;
    }

    return found;
  }

  countAll() {
    return this._inviteCode.model.inviteCode.count();
  }

  list() {
    return this._inviteCode.model.inviteCode.findMany({
      orderBy: { createdAt: 'desc' },
    });
  }

  create(data: {
    code: string;
    label?: string;
    expiresAt?: Date | null;
    tier?: SubscriptionTier | null;
    isLifetime?: boolean;
    maxUses?: number | null;
  }) {
    return this._inviteCode.model.inviteCode.create({
      data: {
        code: data.code,
        label: data.label,
        expiresAt: data.expiresAt ?? null,
        tier: data.tier ?? null,
        isLifetime: data.isLifetime ?? false,
        maxUses: data.maxUses ?? null,
      },
    });
  }

  update(
    id: string,
    data: {
      label?: string;
      active?: boolean;
      expiresAt?: Date | null;
      tier?: SubscriptionTier | null;
      isLifetime?: boolean;
      maxUses?: number | null;
    }
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
