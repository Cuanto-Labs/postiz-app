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
import { User } from '@prisma/client';
import { ApiTags } from '@nestjs/swagger';
import { ErrorsService } from '@gitroom/nestjs-libraries/database/prisma/errors/errors.service';
import { AdminStatsService } from '@gitroom/nestjs-libraries/database/prisma/admin-stats/admin-stats.service';
import { InviteCodesService } from '@gitroom/nestjs-libraries/database/prisma/invite-codes/invite-codes.service';
import { ioRedis } from '@gitroom/nestjs-libraries/redis/redis.service';
import { REDIS_KEY_ENABLED, socialIntegrationList } from '@gitroom/nestjs-libraries/integrations/integration.manager';
import dayjs from 'dayjs';

@ApiTags('Admin')
@Controller('/admin')
export class AdminController {
  constructor(
    private _errorsService: ErrorsService,
    private _adminStatsService: AdminStatsService,
    private _inviteCodesService: InviteCodesService
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

  @Get('/invite-codes')
  async listInviteCodes(@GetUserFromRequest() user: User) {
    this.assertSuperAdmin(user);
    return this._inviteCodesService.list();
  }

  @Post('/invite-codes')
  async createInviteCode(
    @GetUserFromRequest() user: User,
    @Body() body: { code?: string; label?: string; expiresAt?: string }
  ) {
    this.assertSuperAdmin(user);
    const code = (body.code || '').trim();
    if (!code) {
      throw new HttpException('Code is required', 400);
    }
    return this._inviteCodesService.create({
      code,
      label: body.label?.trim() || undefined,
      expiresAt: body.expiresAt ? new Date(body.expiresAt) : null,
    });
  }

  @Put('/invite-codes/:id')
  async updateInviteCode(
    @GetUserFromRequest() user: User,
    @Param('id') id: string,
    @Body() body: { label?: string; active?: boolean; expiresAt?: string | null }
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
    });
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
