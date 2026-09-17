import { Controller, Get, HttpException, Param, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Organization } from '@prisma/client';
import { IntegrationService } from '@gitroom/nestjs-libraries/database/prisma/integrations/integration.service';
import { IntegrationManager } from '@gitroom/nestjs-libraries/integrations/integration.manager';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import { getMediaLimits } from '@gitroom/nestjs-libraries/mobile/media/media-limits';
import { ioRedis } from '@gitroom/nestjs-libraries/redis/redis.service';
import { CheckPolicies } from '@gitroom/backend/services/auth/permissions/permissions.ability';
import {
  AuthorizationActions,
  Sections,
} from '@gitroom/backend/services/auth/permissions/permission.exception.class';

@ApiTags('Mobile Channels')
@ApiBearerAuth()
@Controller('/mobile/v1/channels')
export class MobileChannelsController {
  constructor(
    private _integrationService: IntegrationService,
    private _integrationManager: IntegrationManager
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
