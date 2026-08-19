import { Injectable, OnModuleInit } from '@nestjs/common';
import { InviteCodesRepository } from '@gitroom/nestjs-libraries/database/prisma/invite-codes/invite-codes.repository';
import { InviteCode, SubscriptionTier } from '@prisma/client';

@Injectable()
export class InviteCodesService implements OnModuleInit {
  constructor(private _repository: InviteCodesRepository) {}

  /**
   * One-time migration of the old env allow-list into the table, so the codes
   * baked into the landing pages keep working the moment validation moves to
   * the DB. Runs only when the table is empty, so it never fights admin edits
   * (a deleted seed code stays deleted).
   */
  async onModuleInit() {
    try {
      if ((await this._repository.countAll()) > 0) {
        return;
      }
      const seeds = (process.env.REGISTRATION_CODE || '')
        .split(',')
        .map((code) => code.trim())
        .filter(Boolean);
      for (const code of seeds) {
        await this._repository.upsertSeed(
          code,
          'Seeded from REGISTRATION_CODE'
        );
      }
    } catch (err) {
      // Seeding is best-effort — a failure here must not stop the app booting.
      console.error('Invite code seed failed', err);
    }
  }

  /**
   * Resolve a code for registration without consuming it. An empty/absent code
   * resolves to `{ accepted: true, code: null }` — codes are optional, the
   * complimentary tier is granted regardless — so only a *non-empty,
   * unrecognised* code is rejected.
   *
   * Consumption is deliberately NOT done here. The caller decides when the
   * signup actually succeeded and calls `consume()` exactly once, so a code is
   * never spent by a registration that then failed, and never counted twice
   * when it also grants a tier.
   */
  async resolveForRegistration(
    code?: string
  ): Promise<{ accepted: boolean; code: InviteCode | null }> {
    if (!code) {
      return { accepted: true, code: null };
    }
    const found = await this._repository.findUsable(code);
    if (!found) {
      return { accepted: false, code: null };
    }
    return { accepted: true, code: found };
  }

  /**
   * True when the code may be used for registration. Kept as the thin boolean
   * wrapper the auth flow used before tiers existed.
   */
  async isAcceptable(code?: string): Promise<boolean> {
    return (await this.resolveForRegistration(code)).accepted;
  }

  /** A code that is usable AND actually grants a plan. */
  async findRedeemable(code: string) {
    const found = await this._repository.findUsable(code);
    if (!found || !found.tier) {
      return null;
    }
    return found;
  }

  /** Bump `timesUsed`. Best-effort — never block the flow that granted access. */
  consume(id: string) {
    return this._repository.markUsed(id).catch(() => {});
  }

  list() {
    return this._repository.list();
  }

  create(data: {
    code: string;
    label?: string;
    expiresAt?: Date | null;
    tier?: SubscriptionTier | null;
    isLifetime?: boolean;
    maxUses?: number | null;
    durationDays?: number | null;
  }) {
    return this._repository.create(data);
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
      durationDays?: number | null;
    }
  ) {
    return this._repository.update(id, data);
  }

  delete(id: string) {
    return this._repository.delete(id);
  }
}
