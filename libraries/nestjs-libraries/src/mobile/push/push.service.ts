import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PushDeviceRepository } from '@gitroom/nestjs-libraries/mobile/push/push-device.repository';
import { ApnsClient } from '@gitroom/nestjs-libraries/mobile/push/apns.client';
import { OrganizationRepository } from '@gitroom/nestjs-libraries/database/prisma/organizations/organization.repository';

export type PushEventKind =
  | 'post.published'
  | 'post.failed'
  | 'channel.reconnect_needed';

export interface PushEvent {
  kind: PushEventKind;
  title: string;
  body: string;
  link?: string;
}

export type PushPrefs = Partial<Record<PushEventKind, boolean>>;

export const CATEGORY_BY_KIND: Record<PushEventKind, string> = {
  'post.published': 'POST_PUBLISHED',
  'post.failed': 'POST_FAILED',
  'channel.reconnect_needed': 'CHANNEL_RECONNECT',
};

const URL_REGEX = /https?:\/\/\S+/;
const RECONNECT_REGEX = /(could not refresh|reconnect|refresh)/i;
const PUBLISHED_REGEX = /has been published/i;

@Injectable()
export class PushService {
  constructor(
    private _pushDeviceRepository: PushDeviceRepository,
    private _apnsClient: ApnsClient,
    private _organizationRepository: OrganizationRepository
  ) {}

  async registerDevice(
    userId: string,
    orgId: string | undefined,
    dto: {
      apnsToken: string;
      environment: string;
      bundleId?: string;
      locale?: string;
      timezone?: string;
      prefs?: PushPrefs;
    }
  ) {
    return this._pushDeviceRepository.upsertByToken({
      userId,
      organizationId: orgId,
      apnsToken: dto.apnsToken,
      environment: dto.environment,
      bundleId:
        dto.bundleId ||
        process.env.APNS_DEFAULT_TOPIC ||
        'com.cuantolabs.socials',
      locale: dto.locale,
      timezone: dto.timezone,
      prefs: dto.prefs,
    });
  }

  async unregisterDevice(userId: string, apnsToken: string) {
    await this._pushDeviceRepository.deleteByToken(userId, apnsToken);
    return { ok: true };
  }

  async getPrefs(userId: string, apnsToken: string) {
    const device = await this._pushDeviceRepository.findByToken(
      userId,
      apnsToken
    );
    if (!device) {
      throw new NotFoundException('device not found');
    }
    return { prefs: device.prefs };
  }

  async setPrefs(userId: string, apnsToken: string, prefs: PushPrefs) {
    const validKinds = Object.keys(CATEGORY_BY_KIND);
    const unknownKey = Object.keys(prefs || {}).find(
      (key) => !validKinds.includes(key)
    );
    if (unknownKey) {
      throw new BadRequestException(`unknown pref key: ${unknownKey}`);
    }

    const result = await this._pushDeviceRepository.updatePrefs(
      userId,
      apnsToken,
      prefs
    );
    if (!result || result.count === 0) {
      throw new NotFoundException('device not found');
    }
    return { prefs };
  }

  async deleteAllForUser(userId: string) {
    return this._pushDeviceRepository.deleteAllForUser(userId);
  }

  classify(
    subject: string,
    message: string,
    type: 'success' | 'fail' | 'info'
  ): PushEvent | null {
    if (type === 'fail') {
      return {
        kind: 'post.failed',
        title: subject,
        body: message,
      };
    }

    if (type === 'success' && PUBLISHED_REGEX.test(subject)) {
      const urlMatch = message.match(URL_REGEX);
      return {
        kind: 'post.published',
        title: subject,
        body: message,
        ...(urlMatch ? { link: urlMatch[0] } : {}),
      };
    }

    if (type === 'info' && RECONNECT_REGEX.test(subject + message)) {
      return {
        kind: 'channel.reconnect_needed',
        title: subject,
        body: message,
      };
    }

    return null;
  }

  async notifyOrg(orgId: string, event: PushEvent) {
    let sent = 0;
    let failed = 0;
    let disabled = 0;

    const org = await this._organizationRepository.getAllUsersOrgs(orgId);
    const userIds = (org?.users || []).map((u: any) => u.user.id);
    if (!userIds.length) {
      return { sent, failed, disabled };
    }

    const devices = await this._pushDeviceRepository.listActiveForUsers(
      userIds
    );

    for (const device of devices) {
      if ((device.prefs as PushPrefs)?.[event.kind] === false) {
        continue;
      }

      const result = await this._apnsClient.send({
        token: device.apnsToken,
        environment: device.environment as any,
        topic: device.bundleId,
        collapseId: event.link,
        payload: {
          aps: {
            alert: { title: event.title, body: event.body },
            sound: 'default',
            category: CATEGORY_BY_KIND[event.kind],
            'thread-id': event.kind,
          },
          kind: event.kind,
          link: event.link,
        },
      });

      if (result.ok) {
        sent++;
      } else {
        failed++;
      }

      if (result.unregistered) {
        await this._pushDeviceRepository.disableByToken(device.apnsToken);
        disabled++;
      }
    }

    return { sent, failed, disabled };
  }

  async notifyFromNotification(
    orgId: string,
    subject: string,
    message: string,
    type: 'success' | 'fail' | 'info'
  ) {
    try {
      const event = this.classify(subject, message, type);
      if (!event) {
        return { sent: 0, failed: 0, disabled: 0 };
      }
      return await this.notifyOrg(orgId, event);
    } catch {
      return { sent: 0, failed: 0, disabled: 0 };
    }
  }
}
