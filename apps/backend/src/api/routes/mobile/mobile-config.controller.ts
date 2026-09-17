import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { IntegrationManager } from '@gitroom/nestjs-libraries/integrations/integration.manager';

@ApiTags('Mobile Config')
@Controller('/mobile/v1/config')
export class MobileConfigController {
  constructor(private _integrationManager: IntegrationManager) {}

  @Get('/')
  @ApiOperation({
    summary:
      'Public app config: min supported app version, enabled providers and support/legal links',
  })
  async config() {
    const { social } = await this._integrationManager.getAllIntegrations();

    return {
      minVersion: process.env.MOBILE_MIN_APP_VERSION || '1.0.0',
      providers: social
        .filter((p) => !this._integrationManager.isHiddenProvider(p.identifier))
        .map((p) => ({ identifier: p.identifier, name: p.name })),
      links: {
        support:
          process.env.MOBILE_SUPPORT_URL ||
          'https://socials.cuantolabs.com/support',
        terms:
          process.env.MOBILE_TERMS_URL ||
          'https://socials.cuantolabs.com/terms',
        privacy:
          process.env.MOBILE_PRIVACY_URL ||
          'https://socials.cuantolabs.com/privacy',
      },
    };
  }
}
