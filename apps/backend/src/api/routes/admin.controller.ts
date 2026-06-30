import {
  Body,
  Controller,
  Delete,
  Get,
  HttpException,
  Param,
  Put,
  Query,
} from '@nestjs/common';
import { GetUserFromRequest } from '@gitroom/nestjs-libraries/user/user.from.request';
import { User } from '@prisma/client';
import { ApiTags } from '@nestjs/swagger';
import { ErrorsService } from '@gitroom/nestjs-libraries/database/prisma/errors/errors.service';
import { AdminStatsService } from '@gitroom/nestjs-libraries/database/prisma/admin-stats/admin-stats.service';
import { ioRedis } from '@gitroom/nestjs-libraries/redis/redis.service';
import { REDIS_KEY_ENABLED, socialIntegrationList } from '@gitroom/nestjs-libraries/integrations/integration.manager';
import { PrismaService } from '@gitroom/nestjs-libraries/database/prisma/prisma.service';
import { AGENT_PROVIDERS, activeProviderConfig } from '@gitroom/nestjs-libraries/chat/load.tools.service';
import dayjs from 'dayjs';

export const REDIS_KEY_AGENT_MODEL = 'cuanto:config:agent_model';

@ApiTags('Admin')
@Controller('/admin')
export class AdminController {
  constructor(
    private _errorsService: ErrorsService,
    private _adminStatsService: AdminStatsService,
    private _prisma: PrismaService
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

  // ── Live config ────────────────────────────────────────────────────────────

  @Get('/config')
  async getConfig(@GetUserFromRequest() user: User) {
    this.assertSuperAdmin(user);
    const redisModel = await ioRedis.get(REDIS_KEY_AGENT_MODEL);
    return {
      provider: {
        active: process.env.AGENT_PROVIDER || 'opencode',
        available: Object.keys(AGENT_PROVIDERS),
        note: 'Switching provider requires a Railway redeploy (env var change).',
      },
      model: {
        env: process.env.AGENT_MODEL || activeProviderConfig.defaultModel,
        redis: redisModel || null,
        effective: redisModel || process.env.AGENT_MODEL || activeProviderConfig.defaultModel,
        note: 'redis value overrides env for copilot endpoints; takes effect immediately.',
      },
      rateLimits: {
        api: Number(process.env.API_LIMIT ?? 90),
        ai: Number(process.env.AI_LIMIT ?? 20),
        note: 'Changing limits requires a Railway redeploy (env var change).',
      },
    };
  }

  @Put('/config')
  async setConfig(
    @GetUserFromRequest() user: User,
    @Body() body: { model?: string }
  ) {
    this.assertSuperAdmin(user);
    if (body.model !== undefined) {
      if (body.model === '') {
        await ioRedis.del(REDIS_KEY_AGENT_MODEL);
      } else {
        await ioRedis.set(REDIS_KEY_AGENT_MODEL, body.model);
      }
    }
    return this.getConfig(user);
  }

  // ── Users ──────────────────────────────────────────────────────────────────

  @Get('/users')
  async listUsers(
    @GetUserFromRequest() user: User,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('email') email?: string
  ) {
    this.assertSuperAdmin(user);
    const take = Math.min(Number(limit ?? 50), 200);
    const skip = Number(page ?? 0) * take;

    const [total, users] = await Promise.all([
      this._prisma.user.count({
        where: email ? { email: { contains: email, mode: 'insensitive' } } : {},
      }),
      this._prisma.user.findMany({
        where: email ? { email: { contains: email, mode: 'insensitive' } } : {},
        select: {
          id: true,
          email: true,
          name: true,
          isSuperAdmin: true,
          activated: true,
          createdAt: true,
          lastOnline: true,
          providerName: true,
          _count: { select: { organizations: true } },
        },
        orderBy: { createdAt: 'desc' },
        take,
        skip,
      }),
    ]);

    return { total, page: Number(page ?? 0), limit: take, users };
  }

  // ── Organizations ──────────────────────────────────────────────────────────

  @Get('/orgs')
  async listOrgs(
    @GetUserFromRequest() user: User,
    @Query('page') page?: string,
    @Query('limit') limit?: string
  ) {
    this.assertSuperAdmin(user);
    const take = Math.min(Number(limit ?? 50), 200);
    const skip = Number(page ?? 0) * take;

    const [total, orgs] = await Promise.all([
      this._prisma.organization.count(),
      this._prisma.organization.findMany({
        select: {
          id: true,
          name: true,
          createdAt: true,
          isTrailing: true,
          _count: {
            select: {
              users: true,
              Integration: true,
              post: true,
            },
          },
          users: {
            take: 1,
            select: {
              user: { select: { email: true } },
              role: true,
            },
            where: { role: 'SUPERADMIN' },
          },
        },
        orderBy: { createdAt: 'desc' },
        take,
        skip,
      }),
    ]);

    return {
      total,
      page: Number(page ?? 0),
      limit: take,
      orgs: orgs.map((o) => ({
        id: o.id,
        name: o.name,
        createdAt: o.createdAt,
        isTrailing: o.isTrailing,
        owner: o.users[0]?.user?.email ?? null,
        members: o._count.users,
        channels: o._count.Integration,
        posts: o._count.post,
      })),
    };
  }

  @Put('/orgs/:id/suspend')
  async suspendOrg(
    @GetUserFromRequest() user: User,
    @Param('id') orgId: string,
    @Body() body: { suspended: boolean }
  ) {
    this.assertSuperAdmin(user);
    await this._prisma.userOrganization.updateMany({
      where: { organizationId: orgId },
      data: { disabled: body.suspended },
    });
    return { orgId, suspended: body.suspended };
  }

  // ── Posts (recent scheduled / failed) ──────────────────────────────────────

  @Get('/posts')
  async listPosts(
    @GetUserFromRequest() user: User,
    @Query('limit') limit?: string,
    @Query('state') state?: string,
    @Query('org') orgId?: string
  ) {
    this.assertSuperAdmin(user);
    const take = Math.min(Number(limit ?? 20), 100);

    const posts = await this._prisma.post.findMany({
      where: {
        deletedAt: null,
        parentPostId: null,
        ...(orgId ? { organizationId: orgId } : {}),
        ...(state ? { state: state as any } : {}),
      },
      select: {
        id: true,
        state: true,
        publishDate: true,
        organizationId: true,
        integration: { select: { providerIdentifier: true, name: true } },
        _count: { select: { childrenPost: true } },
      },
      orderBy: { publishDate: 'desc' },
      take,
    });

    return { posts };
  }

  @Delete('/posts/:id')
  async deletePost(
    @GetUserFromRequest() user: User,
    @Param('id') postId: string
  ) {
    this.assertSuperAdmin(user);
    await this._prisma.post.updateMany({
      where: { id: postId, parentPostId: null },
      data: { deletedAt: new Date() },
    });
    return { deleted: postId };
  }
}
