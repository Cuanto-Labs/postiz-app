import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Organization } from '@prisma/client';
import { IntegrationService } from '@gitroom/nestjs-libraries/database/prisma/integrations/integration.service';
import { IntegrationManager } from '@gitroom/nestjs-libraries/integrations/integration.manager';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import { getMediaLimits } from '@gitroom/nestjs-libraries/mobile/media/media-limits';

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
}
