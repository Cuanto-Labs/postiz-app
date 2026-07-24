import { Injectable, OnModuleInit } from '@nestjs/common';
import { InviteCodesRepository } from '@gitroom/nestjs-libraries/database/prisma/invite-codes/invite-codes.repository';

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
   * True when the code may be used for registration. An empty/absent code is
   * "valid" — codes are optional, the complimentary tier is granted regardless
   * — so only a *non-empty, unrecognised* code is rejected. Bumps usage on a
   * hit so the admin list shows which codes are pulling their weight.
   */
  async isAcceptable(code?: string): Promise<boolean> {
    if (!code) {
      return true;
    }
    const found = await this._repository.findUsable(code);
    if (!found) {
      return false;
    }
    this._repository.markUsed(found.id).catch(() => {});
    return true;
  }

  list() {
    return this._repository.list();
  }

  create(data: { code: string; label?: string; expiresAt?: Date | null }) {
    return this._repository.create(data);
  }

  update(
    id: string,
    data: { label?: string; active?: boolean; expiresAt?: Date | null }
  ) {
    return this._repository.update(id, data);
  }

  delete(id: string) {
    return this._repository.delete(id);
  }
}
