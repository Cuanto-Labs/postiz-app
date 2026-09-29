import { Injectable } from '@nestjs/common';
import { pricing } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/pricing';
import { SubscriptionRepository } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/subscription.repository';
import { IntegrationService } from '@gitroom/nestjs-libraries/database/prisma/integrations/integration.service';
import { OrganizationService } from '@gitroom/nestjs-libraries/database/prisma/organizations/organization.service';
import { Organization, SubscriptionTier } from '@prisma/client';
import dayjs from 'dayjs';
import { makeId } from '@gitroom/nestjs-libraries/services/make.is';
import { activeSubscriptionTier } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/free.tier';
import { NotificationService } from '@gitroom/nestjs-libraries/database/prisma/notifications/notification.service';
import {
  tierChangeEmailHtml,
  tierChangeSubject,
} from '@gitroom/nestjs-libraries/database/prisma/subscriptions/tier.change.email';
import { describeTierChange } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/tier.diff';

@Injectable()
export class SubscriptionService {
  constructor(
    private readonly _subscriptionRepository: SubscriptionRepository,
    private readonly _integrationService: IntegrationService,
    private readonly _organizationService: OrganizationService,
    private readonly _notificationService: NotificationService
  ) {}

  getSubscriptionByOrganizationId(organizationId: string) {
    return this._subscriptionRepository.getSubscriptionByOrganizationId(
      organizationId
    );
  }

  useCredit<T>(
    organization: Organization,
    type = 'ai_images',
    func: () => Promise<T>,
    amount = 1
  ): Promise<T> {
    return this._subscriptionRepository.useCredit(
      organization,
      type,
      func,
      amount
    );
  }

  canUsePremiumImages(organization: Organization) {
    if (!process.env.STRIPE_PUBLISHABLE_KEY) {
      return true;
    }
    const tier = activeSubscriptionTier(organization) || 'FREE';
    return !!pricing[tier]?.premium_images;
  }

  getCode(code: string) {
    return this._subscriptionRepository.getCode(code);
  }

  grantFreeTier(organizationId: string) {
    return this._subscriptionRepository.grantFreeTier(organizationId);
  }

  // Customer-keyed flows must never touch a subscription owned by another provider
  private async isManagedBy(customerId: string, provider: string) {
    const current =
      await this._subscriptionRepository.getSubscriptionByCustomerId(
        customerId
      );
    return !current || current.provider === provider;
  }

  async deleteSubscription(customerId: string, provider: string) {
    if (!(await this.isManagedBy(customerId, provider))) {
      return { count: 0 };
    }
    await this.modifySubscription(
      customerId,
      pricing.FREE.channel || 0,
      'FREE'
    );
    return this._subscriptionRepository.deleteSubscriptionByCustomerId(
      customerId,
      provider
    );
  }

  // Store-managed subscriptions (RevenueCat etc.) have no Stripe customer, they are keyed by org
  async deleteSubscriptionByOrgId(organizationId: string, provider: string) {
    const current = await this._subscriptionRepository.getSubscriptionByOrgId(
      organizationId
    );
    if (!current || current.provider !== provider || current.isLifetime) {
      return false;
    }

    await this.modifySubscriptionByOrg(
      organizationId,
      pricing.FREE.channel || 0,
      'FREE'
    );
    return this._subscriptionRepository.deleteSubscriptionByOrgId(
      organizationId,
      provider
    );
  }

  updateCustomerId(organizationId: string, customerId: string) {
    return this._subscriptionRepository.updateCustomerId(
      organizationId,
      customerId
    );
  }

  async checkSubscription(organizationId: string, subscriptionId: string) {
    return await this._subscriptionRepository.checkSubscription(
      organizationId,
      subscriptionId
    );
  }

  async modifySubscriptionByOrg(
    organizationId: string,
    totalChannels: number,
    billing: 'FREE' | 'STANDARD' | 'TEAM' | 'PRO' | 'ULTIMATE'
  ) {
    if (!organizationId) {
      return false;
    }

    const getCurrentSubscription =
      (await this._subscriptionRepository.getSubscriptionByOrgId(
        organizationId
      ))!;

    const from = pricing[getCurrentSubscription?.subscriptionTier || 'FREE'];
    const to = pricing[billing];

    const currentTotalChannels = (
      await this._integrationService.getIntegrationsList(organizationId)
    ).filter((f) => !f.disabled);

    if (currentTotalChannels.length > totalChannels) {
      await this._integrationService.disableIntegrations(
        organizationId,
        currentTotalChannels.length - totalChannels
      );
    }

    if (from.team_members && !to.team_members) {
      await this._organizationService.disableOrEnableNonSuperAdminUsers(
        organizationId,
        true
      );
    }

    if (!from.team_members && to.team_members) {
      await this._organizationService.disableOrEnableNonSuperAdminUsers(
        organizationId,
        false
      );
    }

    if (billing === 'FREE') {
      await this._integrationService.changeActiveCron(organizationId);
    }

    return true;
  }

  async modifySubscription(
    customerId: string,
    totalChannels: number,
    billing: 'FREE' | 'STANDARD' | 'TEAM' | 'PRO' | 'ULTIMATE'
  ) {
    if (!customerId) {
      return false;
    }

    const getOrgByCustomerId =
      await this._subscriptionRepository.getOrganizationByCustomerId(
        customerId
      );

    const getCurrentSubscription =
      (await this._subscriptionRepository.getSubscriptionByCustomerId(
        customerId
      ))!;

    if (
      !getOrgByCustomerId ||
      (getCurrentSubscription && getCurrentSubscription?.isLifetime)
    ) {
      return false;
    }

    const from = pricing[getCurrentSubscription?.subscriptionTier || 'FREE'];
    const to = pricing[billing];

    const currentTotalChannels = (
      await this._integrationService.getIntegrationsList(
        getOrgByCustomerId?.id!
      )
    ).filter((f) => !f.disabled);

    if (currentTotalChannels.length > totalChannels) {
      await this._integrationService.disableIntegrations(
        getOrgByCustomerId?.id!,
        currentTotalChannels.length - totalChannels
      );
    }

    if (from.team_members && !to.team_members) {
      await this._organizationService.disableOrEnableNonSuperAdminUsers(
        getOrgByCustomerId?.id!,
        true
      );
    }

    if (!from.team_members && to.team_members) {
      await this._organizationService.disableOrEnableNonSuperAdminUsers(
        getOrgByCustomerId?.id!,
        false
      );
    }

    if (billing === 'FREE') {
      await this._integrationService.changeActiveCron(getOrgByCustomerId?.id!);
    }

    return true;
  }

  async createOrUpdateSubscription(
    provider: string,
    isTrailing: boolean,
    identifier: string,
    customerId: string,
    totalChannels: number,
    billing: 'STANDARD' | 'TEAM' | 'PRO' | 'ULTIMATE',
    period: 'MONTHLY' | 'YEARLY',
    cancelAt: number | null,
    code?: string,
    org?: string,
    isLifetime?: boolean
  ) {
    if (!code) {
      if (!(await this.isManagedBy(customerId, provider))) {
        return {};
      }
      try {
        const load = await this.modifySubscription(
          customerId,
          totalChannels,
          billing
        );
        if (!load) {
          return {};
        }
      } catch (e) {
        return {};
      }
    }
    return this._subscriptionRepository.createOrUpdateSubscription(
      provider,
      isTrailing,
      identifier,
      customerId,
      totalChannels,
      billing,
      period,
      cancelAt,
      code,
      org ? { id: org } : undefined,
      isLifetime
    );
  }

  async createOrUpdateSubscriptionByOrg(
    isTrailing: boolean,
    organizationId: string,
    provider: string,
    identifier: string,
    totalChannels: number,
    billing: 'STANDARD' | 'TEAM' | 'PRO' | 'ULTIMATE',
    period: 'MONTHLY' | 'YEARLY',
    cancelAt: number | null
  ) {
    const current = await this._subscriptionRepository.getSubscriptionByOrgId(
      organizationId
    );
    if (current && (current.isLifetime || current.provider !== provider)) {
      return {};
    }

    try {
      const load = await this.modifySubscriptionByOrg(
        organizationId,
        totalChannels,
        billing
      );
      if (!load) {
        return {};
      }
    } catch (e) {
      return {};
    }

    return this._subscriptionRepository.createOrUpdateSubscription(
      provider,
      isTrailing,
      identifier,
      '',
      totalChannels,
      billing,
      period,
      cancelAt,
      undefined,
      { id: organizationId }
    );
  }

  getSubscriptionByIdentifier(identifier: string) {
    return this._subscriptionRepository.getSubscriptionByIdentifier(identifier);
  }

  async getSubscription(organizationId: string) {
    return this._subscriptionRepository.getSubscription(organizationId);
  }

  async checkCredits(organization: Organization, checkType = 'ai_images') {
    // Through the helper so a lapsed complimentary grant stops granting credits
    // — reading `subscriptionTier` directly ignores `cancelAt` entirely.
    const type = activeSubscriptionTier(organization) || 'FREE';
    const limit =
      checkType === 'ai_images'
        ? pricing[type].image_generation_count
        : pricing[type].generate_videos;

    if (!limit) {
      return { credits: 0 };
    }

    // FREE has no subscription row to anchor a billing month on, so its
    // allowance resets on the 1st of the calendar month instead.
    // @ts-ignore
    const subscribedAt = organization.subscription?.createdAt;
    let checkFromMonth = dayjs().startOf('month');
    if (type !== 'FREE' && subscribedAt) {
      let date = dayjs(subscribedAt);
      while (date.isBefore(dayjs())) {
        date = date.add(1, 'month');
      }
      checkFromMonth = date.subtract(1, 'month');
    }

    const totalUse = await this._subscriptionRepository.getCreditsFrom(
      organization.id,
      checkFromMonth,
      checkType
    );

    return {
      credits: limit - totalUse,
    };
  }

  /**
   * Grant a plan with no money changing hands — a promo code, at signup or
   * redeemed later. Deliberately does NOT touch Stripe: a comped org usually
   * has no customer, and `modifySubscription` would fail on it, so a `code` is
   * always passed to short-circuit that path.
   *
   * `isTrailing: false` is what ends the complimentary trial — the repository
   * writes it onto the organization alongside `allowTrial: false`.
   */
  async grantTierFromCode(
    orgId: string,
    tier: SubscriptionTier,
    code: string,
    isLifetime: boolean,
    durationDays?: number | null,
    durationMonths?: number | null
  ) {
    return this.applyTier({
      orgId,
      tier,
      identifier: code,
      isLifetime,
      durationDays,
      durationMonths,
    });
  }

  /**
   * The single place a comped plan is applied — code redemption, signup, and an
   * operator acting from the admin panel all land here, so the write, the
   * verification, and the customer email can never diverge between them.
   *
   * `notify` exists because an operator sometimes wants to correct a mistake
   * without emailing the customer about it.
   */
  async applyTier({
    orgId,
    tier,
    identifier,
    isLifetime,
    durationDays,
    durationMonths,
    notify = true,
    reason,
  }: {
    orgId: string;
    tier: SubscriptionTier;
    identifier: string;
    isLifetime: boolean;
    durationDays?: number | null;
    durationMonths?: number | null;
    notify?: boolean;
    reason?: string;
  }) {
    const code = identifier;
    const previous = await this._subscriptionRepository.getSubscriptionByOrgId(
      orgId
    );
    const from = previous?.subscriptionTier ?? null;
    // Counted from redemption, not from a fixed date, so one code behaves the
    // same whenever it is used. A lifetime grant ignores duration entirely.
    //
    // Months are added as calendar months, so a grant made on the 19th ends on
    // the 19th — dayjs clamps where the target month is shorter (31 Jan + 1
    // month = 28 Feb), which is the conventional behaviour for billing dates.
    const expiry = isLifetime
      ? null
      : durationMonths
      ? dayjs().add(durationMonths, 'month')
      : durationDays
      ? dayjs().add(durationDays, 'day')
      : null;

    const cancelAt = expiry ? Math.floor(expiry.valueOf() / 1000) : null;

    // Enforce the new plan's limits before writing it. This is what actually
    // takes features away on a downgrade — channels over the new cap are
    // disabled (not deleted, so they return on an upgrade) and non-superadmin
    // team members are switched off when the target plan has no team support.
    // It has to run first: it derives the "from" plan from the current
    // subscription row, which the write below replaces.
    //
    // The Stripe-facing `modifySubscription` is deliberately not used — a
    // comped org usually has no Stripe customer, and that variant bails on one.
    if (from !== tier) {
      try {
        await this.modifySubscriptionByOrg(
          orgId,
          pricing[tier].channel!,
          tier as any
        );
      } catch (err) {
        console.error('Could not apply plan limits for', orgId, err);
      }
    }

    await this.createOrUpdateSubscription(
      // Upstream added `provider` as the first argument. A comped grant touches
      // no payment provider at all, so use the value the column already
      // defaults to — every pre-existing row has it, and nothing keys off it
      // for a subscription with no customer.
      'stripe',
      false,
      makeId(10),
      orgId,
      pricing[tier].channel!,
      tier,
      'MONTHLY',
      cancelAt,
      // Namespaced so a promo redemption can never collide with a lifetime-deal
      // code in `usedCodes`, which is unique per code string.
      `promo:${code}:${orgId}`,
      orgId,
      isLifetime
    );

    // Read back rather than trust the write. A grant that silently no-ops (the
    // upsert's where-clause is conditional on `code`) would otherwise be
    // reported to the user as a successful upgrade.
    const written = await this._subscriptionRepository.getSubscriptionByOrgId(
      orgId
    );

    if (
      !written ||
      written.subscriptionTier !== tier ||
      written.totalChannels !== pricing[tier].channel ||
      written.isLifetime !== isLifetime
    ) {
      throw new Error(
        `Grant verification failed for org ${orgId}: expected ${tier}` +
          `/${pricing[tier].channel}ch/lifetime=${isLifetime}, got ` +
          `${written?.subscriptionTier}/${written?.totalChannels}ch/lifetime=${written?.isLifetime}`
      );
    }

    if (notify && from !== tier) {
      // Never let a mail failure undo a grant the customer already has. The
      // plan is applied and verified above; this is an announcement.
      try {
        const payload = {
          from,
          to: tier as string,
          isLifetime,
          expiresAt: written.cancelAt,
          reason,
        };
        await this._notificationService.inAppNotification(
          orgId,
          tierChangeSubject(payload),
          tierChangeEmailHtml(payload),
          true,
          false,
          // 'info' so it reaches people who muted success mail — a plan change
          // is account news, not a notification about their posts.
          'info'
        );
      } catch (err) {
        console.error('Could not announce the tier change for', orgId, err);
      }
    }

    return {
      ...written,
      change: describeTierChange(from, tier as string),
      previousTier: from,
    };
  }

  async addSubscription(
    orgId: string,
    userId: string,
    subscription: any,
    provider: string
  ) {
    await this._subscriptionRepository.setCustomerId(orgId, userId);
    return this.createOrUpdateSubscription(
      provider,
      false,
      makeId(5),
      userId,
      pricing[subscription].channel!,
      subscription,
      'MONTHLY',
      null,
      undefined,
      orgId
    );
  }
}
