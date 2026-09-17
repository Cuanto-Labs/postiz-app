import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { GetUserFromRequest } from '@gitroom/nestjs-libraries/user/user.from.request';
import {
  MobileAiConsentDto,
  MobileAiSuggestDto,
} from '@gitroom/nestjs-libraries/dtos/mobile/mobile-ai.dto';
import { AiConsentRepository } from '@gitroom/nestjs-libraries/mobile/ai/ai-consent.repository';
import { MobileAiService } from '@gitroom/nestjs-libraries/mobile/ai/mobile-ai.service';
import { CheckPolicies } from '@gitroom/backend/services/auth/permissions/permissions.ability';
import {
  AuthorizationActions,
  Sections,
} from '@gitroom/backend/services/auth/permissions/permission.exception.class';

@ApiTags('Mobile AI')
@ApiBearerAuth()
@Controller('/mobile/v1/ai')
export class MobileAiController {
  constructor(
    private _aiConsentRepository: AiConsentRepository,
    private _mobileAiService: MobileAiService
  ) {}

  @Get('/consent')
  @ApiOperation({ summary: 'Get the current AI consent timestamp' })
  async getConsent(@GetUserFromRequest() user: any) {
    return {
      aiConsentAt: await this._aiConsentRepository.getConsentAt(user.id),
    };
  }

  @Post('/consent')
  @ApiOperation({ summary: 'Grant or revoke AI consent' })
  async setConsent(
    @GetUserFromRequest() user: any,
    @Body() body: MobileAiConsentDto
  ) {
    const updated = await this._aiConsentRepository.setConsent(
      user.id,
      body.granted
    );

    return { aiConsentAt: updated.aiConsentAt };
  }

  @Post('/suggest')
  @CheckPolicies([AuthorizationActions.Create, Sections.AI])
  @ApiOperation({ summary: 'Get AI suggestions for a post' })
  async suggest(
    @GetUserFromRequest() user: any,
    @Body() body: MobileAiSuggestDto
  ) {
    return this._mobileAiService.suggest(user.id, body);
  }
}
