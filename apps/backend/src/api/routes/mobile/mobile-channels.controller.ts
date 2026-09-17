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
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Organization } from '@prisma/client';
import { IntegrationService } from '@gitroom/nestjs-libraries/database/prisma/integrations/integration.service';
import { IntegrationManager } from '@gitroom/nestjs-libraries/integrations/integration.manager';
import { PostsService } from '@gitroom/nestjs-libraries/database/prisma/posts/posts.service';
import { pricing } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/pricing';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import { getMediaLimits } from '@gitroom/nestjs-libraries/mobile/media/media-limits';
import { ioRedis } from '@gitroom/nestjs-libraries/redis/redis.service';
import { CheckPolicies } from '@gitroom/backend/services/auth/permissions/permissions.ability';
import {
  AuthorizationActions,
  Sections,
} from '@gitroom/backend/services/auth/permissions/permission.exception.class';
import { IntegrationTimeDto } from '@gitroom/nestjs-libraries/dtos/integrations/integration.time.dto';
import { IntegrationFunctionDto } from '@gitroom/nestjs-libraries/dtos/integrations/integration.function.dto';
import {
  MobileChannelGroupDto,
  MobileChannelNameDto,
  MobileChannelSettingsDto,
} from '@gitroom/nestjs-libraries/dtos/mobile/mobile-channels.dto';
import {
  Disconnect,
  RefreshToken,
} from '@gitroom/nestjs-libraries/integrations/social.abstract';
import { RefreshIntegrationService } from '@gitroom/nestjs-libraries/integrations/refresh.integration.service';
import { timer } from '@gitroom/helpers/utils/timer';
import { uniqBy } from 'lodash';

@ApiTags('Mobile Channels')
@ApiBearerAuth()
@Controller('/mobile/v1/channels')
export class MobileChannelsController {
  constructor(
    private _integrationService: IntegrationService,
    private _integrationManager: IntegrationManager,
    private _postService: PostsService,
    private _refreshIntegrationService: RefreshIntegrationService
  ) {}

  @Get('/')
  @ApiOperation({
    summary: 'List connected channels with status and per-platform limits',
  })
  async list(@GetOrgFromRequest() org: Organization) {
    const integrations = await this._integrationService.getIntegrationsList(
      org.id
    );

    return {
      channels: integrations.map((p: any) => {
        const findIntegration = this._integrationManager.getSocialIntegration(
          p.providerIdentifier
        );

        const verified =
          JSON.parse(p.additionalSettings || '[]')?.find(
            (s: any) => s?.title === 'Verified'
          )?.value || false;

        return {
          id: p.id,
          internalId: p.internalId,
          name: p.name,
          identifier: p.providerIdentifier,
          picture: p.picture || '/no-picture.jpg',
          disabled: p.disabled,
          refreshNeeded: p.refreshNeeded,
          inBetweenSteps: p.inBetweenSteps,
          display: p.profile,
          type: p.type,
          customer: p.customer,
          limits: {
            maxCharacters: findIntegration
              ? findIntegration.maxLength(verified)
              : null,
            editor: findIntegration ? findIntegration.editor : null,
            media: getMediaLimits(p.providerIdentifier),
          },
        };
      }),
    };
  }

  @Get('/customers')
  @ApiOperation({ summary: 'List distinct customer names for the org' })
  getCustomers(@GetOrgFromRequest() org: Organization) {
    return this._integrationService.customers(org.id);
  }

  @Put('/:id/customer-name')
  @ApiOperation({ summary: 'Rename the customer attached to a channel' })
  async updateOnCustomerName(
    @GetOrgFromRequest() org: Organization,
    @Param('id') id: string,
    @Body() body: MobileChannelNameDto
  ) {
    return this._integrationService.updateOnCustomerName(
      org.id,
      id,
      body.name
    );
  }

  @Put('/:id/group')
  @ApiOperation({ summary: 'Set the group a channel belongs to' })
  async updateIntegrationGroup(
    @GetOrgFromRequest() org: Organization,
    @Param('id') id: string,
    @Body() body: MobileChannelGroupDto
  ) {
    return this._integrationService.updateIntegrationGroup(
      org.id,
      id,
      body.group
    );
  }

  @Post('/:id/time')
  @ApiOperation({ summary: 'Set the posting time table for a channel' })
  async setTimes(
    @GetOrgFromRequest() org: Organization,
    @Param('id') id: string,
    @Body() body: IntegrationTimeDto
  ) {
    return this._integrationService.setTimes(org.id, id, body);
  }

  @Post('/:id/settings')
  @ApiOperation({ summary: 'Update provider-specific settings for a channel' })
  async updateProviderSettings(
    @GetOrgFromRequest() org: Organization,
    @Param('id') id: string,
    @Body() body: MobileChannelSettingsDto
  ) {
    return this._integrationService.updateProviderSettings(
      org.id,
      id,
      body.additionalSettings
    );
  }

  @Post('/mentions')
  @ApiOperation({ summary: 'Search cached mentions for a channel' })
  async mentions(
    @GetOrgFromRequest() org: Organization,
    @Body() body: IntegrationFunctionDto
  ) {
    const getIntegration = await this._integrationService.getIntegrationById(
      org.id,
      body.id
    );
    if (!getIntegration) {
      throw new Error('Invalid integration');
    }

    let newList: any[] | { none: true } = [];
    try {
      newList = (await this.functionIntegration(org, body)) || [];
    } catch (err) {
      console.log(err);
    }

    if (!Array.isArray(newList) && newList?.none) {
      return newList;
    }

    const list = await this._integrationService.getMentions(
      getIntegration.providerIdentifier,
      body?.data?.query
    );

    if (Array.isArray(newList) && newList.length) {
      await this._integrationService.insertMentions(
        getIntegration.providerIdentifier,
        newList
          .map((p: any) => ({
            name: p.label || '',
            username: p.id || '',
            image: p.image || '',
            doNotCache: p.doNotCache || false,
          }))
          .filter((f: any) => f.name && !f.doNotCache)
      );
    }

    return uniqBy(
      [
        ...list.map((p) => ({
          id: p.username,
          image: p.image,
          label: p.name,
        })),
        ...(newList as any[]),
      ],
      (p) => p.id
    ).filter((f) => f.label && f.id);
  }

  @Post('/function')
  @ApiOperation({ summary: 'Dispatch a provider-specific function call' })
  async functionIntegration(
    @GetOrgFromRequest() org: Organization,
    @Body() body: IntegrationFunctionDto
  ): Promise<any> {
    const getIntegration = await this._integrationService.getIntegrationById(
      org.id,
      body.id
    );
    if (!getIntegration) {
      throw new Error('Invalid integration');
    }

    const integrationProvider = this._integrationManager.getSocialIntegration(
      getIntegration.providerIdentifier
    );
    if (!integrationProvider) {
      throw new Error('Invalid provider');
    }

    // @ts-ignore
    if (integrationProvider[body.name]) {
      try {
        // @ts-ignore
        const load = await integrationProvider[body.name](
          getIntegration.token,
          body.data,
          getIntegration.internalId,
          getIntegration
        );

        return load;
      } catch (err) {
        // The platform will keep rejecting this channel until the user
        // re-connects it: mark it as needing a refresh instead of retrying.
        if (err instanceof Disconnect) {
          await this._integrationService.disconnectChannel(
            org.id,
            getIntegration
          );
          return false;
        }

        if (err instanceof RefreshToken) {
          const data = await this._refreshIntegrationService.refresh(
            getIntegration
          );

          if (!data) {
            return;
          }

          const { accessToken } = data;

          if (accessToken) {
            if (integrationProvider.refreshWait) {
              await timer(10000);
            }
            return this.functionIntegration(org, body);
          }

          return false;
        }

        return false;
      }
    }
    throw new Error('Function not found');
  }

  @Post('/:id/disable')
  @ApiOperation({ summary: 'Disable a channel' })
  disableChannel(
    @GetOrgFromRequest() org: Organization,
    @Param('id') id: string
  ) {
    return this._integrationService.disableChannel(org.id, id);
  }

  @Post('/:id/enable')
  @ApiOperation({ summary: 'Enable a channel (subject to plan channel cap)' })
  enableChannel(
    @GetOrgFromRequest() org: Organization,
    @Param('id') id: string
  ) {
    return this._integrationService.enableChannel(
      org.id,
      // @ts-ignore
      org?.subscription?.totalChannels || pricing.FREE.channel,
      id
    );
  }

  @Delete('/:id')
  @ApiOperation({ summary: 'Delete a channel and clean up its posts' })
  async deleteChannel(
    @GetOrgFromRequest() org: Organization,
    @Param('id') id: string
  ) {
    const isTherePosts = await this._integrationService.getPostsForChannel(
      org.id,
      id
    );
    if (isTherePosts.length) {
      for (const post of isTherePosts) {
        this._postService.deletePost(org.id, post.group).catch((err) => {});
      }
    }

    return this._integrationService.deleteChannel(org.id, id);
  }

  @Get('/connect/:provider')
  @CheckPolicies([AuthorizationActions.Create, Sections.CHANNEL])
  @ApiOperation({ summary: 'Start the OAuth flow for a provider (mobile)' })
  async connect(
    @Param('provider') provider: string,
    @Query('refresh') refresh: string,
    @Query('externalUrl') externalUrl: string,
    @GetOrgFromRequest() org: Organization
  ) {
    if (
      !(await this._integrationManager.getAllowedSocialsIntegrations()).includes(
        provider
      )
    ) {
      throw new HttpException({ msg: 'Integration not allowed' }, 400);
    }

    const integrationProvider =
      this._integrationManager.getSocialIntegration(provider);

    if (integrationProvider.externalUrl && !externalUrl) {
      throw new HttpException({ msg: 'Missing external url' }, 400);
    }

    const getExternalUrl = integrationProvider.externalUrl
      ? {
          ...(await integrationProvider.externalUrl(externalUrl)),
          instanceUrl: externalUrl,
        }
      : undefined;

    const { codeVerifier, state, url } =
      await integrationProvider.generateAuthUrl(getExternalUrl);

    if (refresh) {
      await ioRedis.set(`refresh:${state}`, refresh, 'EX', 3600);
    }

    await ioRedis.set(`organization:${state}`, org.id, 'EX', 3600);
    await ioRedis.set(`login:${state}`, codeVerifier, 'EX', 3600);
    await ioRedis.set(
      `external:${state}`,
      JSON.stringify(getExternalUrl),
      'EX',
      3600
    );
    await ioRedis.set(`mobile:${state}`, '1', 'EX', 3600);
    await ioRedis.set(
      `redirect:${state}`,
      `${process.env.FRONTEND_URL}/m/connected?provider=${provider}`,
      'EX',
      3600
    );

    return { url, state };
  }
}
