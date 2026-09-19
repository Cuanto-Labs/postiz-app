import 'reflect-metadata';

import { Injectable } from '@nestjs/common';
import { ioRedis } from '@gitroom/nestjs-libraries/redis/redis.service';
import { XProvider } from '@gitroom/nestjs-libraries/integrations/social/x.provider';
import { SocialProvider } from '@gitroom/nestjs-libraries/integrations/social/social.integrations.interface';
import { LinkedinProvider } from '@gitroom/nestjs-libraries/integrations/social/linkedin.provider';
import { RedditProvider } from '@gitroom/nestjs-libraries/integrations/social/reddit.provider';
import { DevToProvider } from '@gitroom/nestjs-libraries/integrations/social/dev.to.provider';
import { HashnodeProvider } from '@gitroom/nestjs-libraries/integrations/social/hashnode.provider';
import { MediumProvider } from '@gitroom/nestjs-libraries/integrations/social/medium.provider';
import { FacebookProvider } from '@gitroom/nestjs-libraries/integrations/social/facebook.provider';
import { InstagramProvider } from '@gitroom/nestjs-libraries/integrations/social/instagram.provider';
import { YoutubeProvider } from '@gitroom/nestjs-libraries/integrations/social/youtube.provider';
import { TiktokProvider } from '@gitroom/nestjs-libraries/integrations/social/tiktok.provider';
import { TiktokBusinessProvider } from '@gitroom/nestjs-libraries/integrations/social/tiktok.business.provider';
import { PinterestProvider } from '@gitroom/nestjs-libraries/integrations/social/pinterest.provider';
import { DribbbleProvider } from '@gitroom/nestjs-libraries/integrations/social/dribbble.provider';
import { LinkedinPageProvider } from '@gitroom/nestjs-libraries/integrations/social/linkedin.page.provider';
import { ThreadsProvider } from '@gitroom/nestjs-libraries/integrations/social/threads.provider';
import { DiscordProvider } from '@gitroom/nestjs-libraries/integrations/social/discord.provider';
import { SlackProvider } from '@gitroom/nestjs-libraries/integrations/social/slack.provider';
import { MastodonProvider } from '@gitroom/nestjs-libraries/integrations/social/mastodon.provider';
import { BlueskyProvider } from '@gitroom/nestjs-libraries/integrations/social/bluesky.provider';
import { LemmyProvider } from '@gitroom/nestjs-libraries/integrations/social/lemmy.provider';
import { InstagramStandaloneProvider } from '@gitroom/nestjs-libraries/integrations/social/instagram.standalone.provider';
import { FarcasterProvider } from '@gitroom/nestjs-libraries/integrations/social/farcaster.provider';
import { TelegramProvider } from '@gitroom/nestjs-libraries/integrations/social/telegram.provider';
import { NostrProvider } from '@gitroom/nestjs-libraries/integrations/social/nostr.provider';
import { VkProvider } from '@gitroom/nestjs-libraries/integrations/social/vk.provider';
import { WordpressProvider } from '@gitroom/nestjs-libraries/integrations/social/wordpress.provider';
import { ListmonkProvider } from '@gitroom/nestjs-libraries/integrations/social/listmonk.provider';
import { GmbProvider } from '@gitroom/nestjs-libraries/integrations/social/gmb.provider';
import { KickProvider } from '@gitroom/nestjs-libraries/integrations/social/kick.provider';
import { TwitchProvider } from '@gitroom/nestjs-libraries/integrations/social/twitch.provider';
import { SocialAbstract } from '@gitroom/nestjs-libraries/integrations/social.abstract';
import { MoltbookProvider } from '@gitroom/nestjs-libraries/integrations/social/moltbook.provider';
import { SkoolProvider } from '@gitroom/nestjs-libraries/integrations/social/skool.provider';
import { WhopProvider } from '@gitroom/nestjs-libraries/integrations/social/whop.provider';
import { MeweProvider } from '@gitroom/nestjs-libraries/integrations/social/mewe.provider';
import { TumblrProvider } from '@gitroom/nestjs-libraries/integrations/social/tumblr.provider';

// ENABLED_INTEGRATIONS — comma-separated list of provider identifiers to activate.
// When set, only those providers are instantiated and Temporal workers are registered for them.
// Unset = all 33 providers (default, full feature set).
//
// Example env: ENABLED_INTEGRATIONS=x,linkedin,linkedin-page
//
// Boot time impact: each Temporal worker = one Cloud task-queue connection (~100-200ms).
// 33 workers → ~8s boot. 2 workers → ~2-3s boot.
const ENABLED_IDS: Set<string> | null = process.env.ENABLED_INTEGRATIONS
  ? new Set(process.env.ENABLED_INTEGRATIONS.split(',').map((s) => s.trim()))
  : null;

const ALL_PROVIDERS: Array<SocialAbstract & SocialProvider> = [
  new XProvider(),
  new LinkedinProvider(),
  new LinkedinPageProvider(),
  new RedditProvider(),
  new InstagramProvider(),
  new InstagramStandaloneProvider(),
  new FacebookProvider(),
  new ThreadsProvider(),
  new YoutubeProvider(),
  new GmbProvider(),
  new TiktokProvider(),
  new TiktokBusinessProvider(),
  new PinterestProvider(),
  new DribbbleProvider(),
  new DiscordProvider(),
  new SlackProvider(),
  new KickProvider(),
  new TwitchProvider(),
  new MastodonProvider(),
  new BlueskyProvider(),
  new LemmyProvider(),
  new FarcasterProvider(),
  new TelegramProvider(),
  new NostrProvider(),
  new VkProvider(),
  new MediumProvider(),
  new DevToProvider(),
  new HashnodeProvider(),
  new WordpressProvider(),
  new ListmonkProvider(),
  new MoltbookProvider(),
  new WhopProvider(),
  new SkoolProvider(),
  new MeweProvider(),
  new TumblrProvider(),
  // new MastodonCustomProvider(),
];

// Boot-time list — Temporal workers registered from this at startup.
export const socialIntegrationList: Array<SocialAbstract & SocialProvider> = ENABLED_IDS
  ? ALL_PROVIDERS.filter((p) => ENABLED_IDS!.has(p.identifier))
  : ALL_PROVIDERS;

// Redis key for live toggle — overrides boot-time filter for user-facing methods.
// Does NOT affect Temporal workers (those are set at boot).
// Format: comma-separated identifiers, e.g. "x,linkedin,linkedin-page"
export const REDIS_KEY_ENABLED = 'cuanto:enabled_integrations';

// Returns the active enabled set: Redis value > env var > all
async function getEnabledIds(): Promise<Set<string> | null> {
  try {
    const raw = await ioRedis.get(REDIS_KEY_ENABLED);
    if (raw) return new Set(raw.split(',').map((s) => s.trim()));
  } catch {
    // Redis unavailable — fall through to env fallback
  }
  return ENABLED_IDS; // null means "all"
}

@Injectable()
export class IntegrationManager {
  // Both are env-driven so cloud and self-hosted instances can differ:
  // HIDDEN_PROVIDERS ("tiktok,x") hides providers from the add-channel screen,
  // MIGRATE_PROVIDERS ("tiktok:tiktok-business") routes a reconnect of the old
  // provider through the new provider's OAuth and migrates the channel in
  // place, keeping its id, scheduled posts and settings.
  isHiddenProvider(identifier: string) {
    return (process.env.HIDDEN_PROVIDERS || '')
      .split(',')
      .map((p) => p.trim())
      .includes(identifier);
  }

  // Note: a target provider that implements `reConnect` is not supported - the
  // connect callback would run reConnect with the old app-scoped id before the
  // migration is attempted.
  async getMigrationTarget(identifier: string): Promise<string | undefined> {
    const [, target] =
      (process.env.MIGRATE_PROVIDERS || '')
        .split(',')
        .map((p) => p.trim().split(':'))
        .find(([from, to]) => from === identifier && !!to) || [];

    return target &&
      target !== identifier &&
      (await this.getAllowedSocialsIntegrations()).includes(target)
      ? target
      : undefined;
  }

  // Reverse lookup of MIGRATE_PROVIDERS: the providers whose channels a fresh
  // connect of `identifier` should adopt instead of creating a duplicate.
  async getMigrationSources(identifier: string): Promise<string[]> {
    const allowed = await this.getAllowedSocialsIntegrations();
    return (process.env.MIGRATE_PROVIDERS || '')
      .split(',')
      .map((p) => p.trim().split(':'))
      .filter(
        ([from, to]) =>
          to === identifier &&
          !!from &&
          from !== identifier &&
          allowed.includes(from)
      )
      .map(([from]) => from);
  }

  async getAllIntegrations() {
    const enabled = await getEnabledIds();
    const visible = enabled
      ? socialIntegrationList.filter((p) => enabled.has(p.identifier))
      : socialIntegrationList;

    return {
      social: await Promise.all(
        visible
          .filter((p) => !this.isHiddenProvider(p.identifier))
          .map(async (p) => ({
            name: p.name,
            identifier: p.identifier,
            toolTip: p.toolTip,
            editor: p.editor,
            isExternal: !!p.externalUrl,
            isWeb3: !!p.isWeb3,
            isChromeExtension: !!p.isChromeExtension,
            ...(p.extensionCookies
              ? { extensionCookies: p.extensionCookies }
              : {}),
            ...(p.customFields ? { customFields: await p.customFields() } : {}),
          }))
      ),
      article: [] as any[],
    };
  }

  getAllTools(): {
    [key: string]: {
      description: string;
      dataSchema: any;
      methodName: string;
    }[];
  } {
    return socialIntegrationList.reduce(
      (all, current) => ({
        ...all,
        [current.identifier]:
          Reflect.getMetadata('custom:tool', current.constructor.prototype) ||
          [],
      }),
      {}
    );
  }

  getAllRulesDescription(): {
    [key: string]: string;
  } {
    return socialIntegrationList.reduce(
      (all, current) => ({
        ...all,
        [current.identifier]:
          Reflect.getMetadata(
            'custom:rules:description',
            current.constructor
          ) || '',
      }),
      {}
    );
  }

  getAllPlugs() {
    return socialIntegrationList
      .map((p) => {
        return {
          name: p.name,
          identifier: p.identifier,
          plugs: (
            Reflect.getMetadata('custom:plug', p.constructor.prototype) || []
          )
            .filter((f: any) => !f.disabled)
            .map((p: any) => ({
              ...p,
              fields: p.fields.map((c: any) => ({
                ...c,
                validation: c?.validation?.toString(),
              })),
            })),
        };
      })
      .filter((f) => f.plugs.length);
  }

  getInternalPlugs(providerName: string) {
    const p = socialIntegrationList.find((p) => p.identifier === providerName)!;
    return {
      internalPlugs:
        (
          Reflect.getMetadata(
            'custom:internal_plug',
            p.constructor.prototype
          ) || []
        ).filter((f: any) => !f.disabled) || [],
    };
  }

  async getAllowedSocialsIntegrations() {
    const enabled = await getEnabledIds();
    const list = enabled
      ? socialIntegrationList.filter((p) => enabled.has(p.identifier))
      : socialIntegrationList;
    return list.map((p) => p.identifier);
  }

  // Sync — used by Temporal posting path. Always has access to all boot-loaded providers
  // regardless of Redis toggle (existing integrations must remain postable after a toggle-off).
  getSocialIntegration(integration: string): SocialProvider {
    return socialIntegrationList.find((i) => i.identifier === integration)!;
  }
}
