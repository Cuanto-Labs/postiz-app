import {
  Body,
  Controller,
  Delete,
  Get,
  HttpException,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { GetUserFromRequest } from '@gitroom/nestjs-libraries/user/user.from.request';
import { SubscriptionTier, User } from '@prisma/client';
import { ApiTags } from '@nestjs/swagger';
import { ErrorsService } from '@gitroom/nestjs-libraries/database/prisma/errors/errors.service';
import { AdminStatsService } from '@gitroom/nestjs-libraries/database/prisma/admin-stats/admin-stats.service';
import { InviteCodesService } from '@gitroom/nestjs-libraries/database/prisma/invite-codes/invite-codes.service';
import { OrganizationService } from '@gitroom/nestjs-libraries/database/prisma/organizations/organization.service';
import { SubscriptionService } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/subscription.service';
import { describeTierChange } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/tier.diff';
import { makeId } from '@gitroom/nestjs-libraries/services/make.is';
import { ioRedis } from '@gitroom/nestjs-libraries/redis/redis.service';
import { REDIS_KEY_ENABLED, socialIntegrationList } from '@gitroom/nestjs-libraries/integrations/integration.manager';
import dayjs from 'dayjs';

/** The tiers a code may grant. Mirrors the Prisma enum, which has no FREE. */
const TIERS: SubscriptionTier[] = ['STANDARD', 'TEAM', 'PRO', 'ULTIMATE'];

@ApiTags('Admin')
@Controller('/admin')
export class AdminController {
  constructor(
    private _errorsService: ErrorsService,
    private _adminStatsService: AdminStatsService,
    private _inviteCodesService: InviteCodesService,
    private _organizationService: OrganizationService,
    private _subscriptionService: SubscriptionService
  ) {}

  private assertSuperAdmin(user: User) {
    if (!user?.isSuperAdmin) {
      throw new HttpException('Unauthorized', 400);
    }
  }

  @Get('/errors')
  async listErrors(
    @GetUserFromRequest() user: User,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('platform') platform?: string,
    @Query('email') email?: string,
    @Query('unknownFirst') unknownFirst?: string
  ) {
    this.assertSuperAdmin(user);
    return this._errorsService.listErrors({
      page: page ? parseInt(page, 10) : 0,
      limit: limit ? parseInt(limit, 10) : 20,
      platform: platform || undefined,
      email: email || undefined,
      unknownFirst: unknownFirst === 'true' || unknownFirst === '1',
    });
  }

  @Get('/errors/platforms')
  async listPlatforms(@GetUserFromRequest() user: User) {
    this.assertSuperAdmin(user);
    return this._errorsService.listPlatforms();
  }

  @Get('/integrations/enabled')
  async getEnabledIntegrations(@GetUserFromRequest() user: User) {
    this.assertSuperAdmin(user);
    const raw = await ioRedis.get(REDIS_KEY_ENABLED);
    const active = raw
      ? raw.split(',').map((s) => s.trim())
      : socialIntegrationList.map((p) => p.identifier);
    return {
      enabled: active,
      available: socialIntegrationList.map((p) => p.identifier),
      source: raw ? 'redis' : 'boot',
    };
  }

  @Put('/integrations/enabled')
  async setEnabledIntegrations(
    @GetUserFromRequest() user: User,
    @Body() body: { enabled: string[] }
  ) {
    this.assertSuperAdmin(user);
    const valid = socialIntegrationList.map((p) => p.identifier);
    const filtered = (body.enabled ?? []).filter((id) => valid.includes(id));
    if (!filtered.length) {
      throw new HttpException('No valid integration identifiers provided', 400);
    }
    await ioRedis.set(REDIS_KEY_ENABLED, filtered.join(','));
    return { enabled: filtered };
  }

  @Delete('/integrations/enabled')
  async resetEnabledIntegrations(@GetUserFromRequest() user: User) {
    this.assertSuperAdmin(user);
    await ioRedis.del(REDIS_KEY_ENABLED);
    return {
      enabled: socialIntegrationList.map((p) => p.identifier),
      source: 'boot',
    };
  }

  @Get('/stats')
  async getStats(
    @GetUserFromRequest() user: User,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('unknownOnly') unknownOnly?: string
  ) {
    this.assertSuperAdmin(user);

    const fromDate = from ? dayjs(from) : dayjs().subtract(30, 'day');
    const toDate = to ? dayjs(to) : dayjs();

    return this._adminStatsService.getStats({
      from: fromDate.startOf('day').toDate(),
      to: toDate.endOf('day').toDate(),
      unknownOnly: unknownOnly === 'true' || unknownOnly === '1',
    });
  }

  /**
   * Find the organizations behind an email address. Support starts from an
   * address, not an org id, so this is the entry point for every manual plan
   * change below.
   */
  @Get('/organizations')
  async searchOrganizations(
    @GetUserFromRequest() user: User,
    @Query('email') email?: string
  ) {
    this.assertSuperAdmin(user);
    const query = (email || '').trim();
    if (query.length < 3) {
      throw new HttpException('Search by at least 3 characters', 400);
    }
    return this._organizationService.searchOrganizationsByUserEmail(query);
  }

  /**
   * Preview a plan change without making it. The operator sees exactly what the
   * customer's email will say before anyone is emailed.
   */
  @Get('/organizations/:id/tier-preview')
  async previewTierChange(
    @GetUserFromRequest() user: User,
    @Param('id') id: string,
    @Query('tier') tier: SubscriptionTier
  ) {
    this.assertSuperAdmin(user);
    const target = this.parseTier(tier);
    if (!target) {
      throw new HttpException('A tier is required', 400);
    }
    const current = await this._subscriptionService.getSubscriptionByOrganizationId(
      id
    );
    return {
      from: current?.subscriptionTier ?? null,
      to: target,
      ...describeTierChange(current?.subscriptionTier ?? null, target),
    };
  }

  /**
   * Apply a plan to an organization by hand. This is the operator counterpart
   * to redeeming a code, and runs through the same applyTier path — same
   * write, same verification, same customer email.
   */
  @Post('/organizations/:id/tier')
  async setOrganizationTier(
    @GetUserFromRequest() user: User,
    @Param('id') id: string,
    @Body()
    body: {
      tier?: SubscriptionTier;
      isLifetime?: boolean;
      durationDays?: number | null;
      durationMonths?: number | null;
      notify?: boolean;
      reason?: string;
    }
  ) {
    this.assertSuperAdmin(user);

    const tier = this.parseTier(body.tier);
    if (!tier) {
      throw new HttpException('A tier is required', 400);
    }

    const org = await this._organizationService.getOrgById(id);
    if (!org) {
      throw new HttpException('Organization not found', 404);
    }

    // A Stripe-billed org must be changed in Stripe, or the next webhook
    // overwrites whatever is written here and the customer gets two
    // contradictory emails.
    if (org.paymentId) {
      throw new HttpException(
        'This organization has a Stripe subscription — change it in Stripe instead',
        400
      );
    }

    const duration = this.parseDuration(body.durationDays, body.durationMonths);

    return this._subscriptionService.applyTier({
      orgId: id,
      tier,
      identifier: `admin:${makeId(8)}`,
      isLifetime: !!body.isLifetime,
      ...duration,
      notify: body.notify !== false,
      reason: body.reason?.trim() || undefined,
    });
  }

  @Get('/invite-codes')
  async listInviteCodes(@GetUserFromRequest() user: User) {
    this.assertSuperAdmin(user);
    return this._inviteCodesService.list();
  }

  @Post('/invite-codes')
  async createInviteCode(
    @GetUserFromRequest() user: User,
    @Body()
    body: {
      code?: string;
      label?: string;
      expiresAt?: string;
      tier?: SubscriptionTier | null;
      isLifetime?: boolean;
      maxUses?: number | null;
      durationDays?: number | null;
      durationMonths?: number | null;
    }
  ) {
    this.assertSuperAdmin(user);
    const code = (body.code || '').trim().toUpperCase();
    if (!code) {
      throw new HttpException('Code is required', 400);
    }
    return this._inviteCodesService.create({
      code,
      label: body.label?.trim() || undefined,
      expiresAt: body.expiresAt ? new Date(body.expiresAt) : null,
      tier: this.parseTier(body.tier),
      isLifetime: !!body.isLifetime,
      maxUses: this.parsePositiveInt(body.maxUses, 'Max uses'),
      ...this.parseDuration(body.durationDays, body.durationMonths),
    });
  }

  @Put('/invite-codes/:id')
  async updateInviteCode(
    @GetUserFromRequest() user: User,
    @Param('id') id: string,
    @Body()
    body: {
      label?: string;
      active?: boolean;
      expiresAt?: string | null;
      tier?: SubscriptionTier | null;
      isLifetime?: boolean;
      maxUses?: number | null;
      durationDays?: number | null;
      durationMonths?: number | null;
    }
  ) {
    this.assertSuperAdmin(user);
    return this._inviteCodesService.update(id, {
      label: body.label,
      active: body.active,
      expiresAt:
        body.expiresAt === undefined
          ? undefined
          : body.expiresAt
          ? new Date(body.expiresAt)
          : null,
      tier: body.tier === undefined ? undefined : this.parseTier(body.tier),
      isLifetime: body.isLifetime,
      maxUses:
        body.maxUses === undefined
          ? undefined
          : this.parsePositiveInt(body.maxUses, 'Max uses'),
      ...(body.durationDays === undefined && body.durationMonths === undefined
        ? {}
        : this.parseDuration(body.durationDays, body.durationMonths)),
    });
  }

  /**
   * Reject an unknown tier loudly rather than silently storing null — a typo'd
   * tier would otherwise produce a code that validates but grants nothing.
   */
  private parseTier(tier?: SubscriptionTier | null) {
    if (!tier) {
      return null;
    }
    if (!TIERS.includes(tier)) {
      throw new HttpException(`Unknown tier: ${tier}`, 400);
    }
    return tier;
  }

  /**
   * Days and months are mutually exclusive — a code that carried both would
   * silently apply only one, and which one is an implementation detail the
   * admin should never have to know.
   */
  private parseDuration(
    days?: number | null,
    months?: number | null
  ): { durationDays: number | null; durationMonths: number | null } {
    const parsedDays = this.parsePositiveInt(days, 'Duration in days');
    const parsedMonths = this.parsePositiveInt(months, 'Duration in months');

    if (parsedDays && parsedMonths) {
      throw new HttpException(
        'Set a duration in days or in months, not both',
        400
      );
    }

    return { durationDays: parsedDays, durationMonths: parsedMonths };
  }

  private parsePositiveInt(value: number | null | undefined, label: string) {
    if (value === null || value === undefined || `${value}` === '') {
      return null;
    }
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed < 1) {
      throw new HttpException(`${label} must be a positive whole number`, 400);
    }
    return parsed;
  }

  @Delete('/invite-codes/:id')
  async deleteInviteCode(
    @GetUserFromRequest() user: User,
    @Param('id') id: string
  ) {
    this.assertSuperAdmin(user);
    return this._inviteCodesService.delete(id);
  }
}
