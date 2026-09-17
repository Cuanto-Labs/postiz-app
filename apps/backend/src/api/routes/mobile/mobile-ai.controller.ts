import { Body, Controller, Get, HttpException, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Organization } from '@prisma/client';
import { GetUserFromRequest } from '@gitroom/nestjs-libraries/user/user.from.request';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import {
  MobileAiConsentDto,
  MobileAiSuggestDto,
} from '@gitroom/nestjs-libraries/dtos/mobile/mobile-ai.dto';
import {
  MobileAiImageDto,
  MobileAiVideoDto,
} from '@gitroom/nestjs-libraries/dtos/mobile/mobile-ai-generate.dto';
import { AiConsentRepository } from '@gitroom/nestjs-libraries/mobile/ai/ai-consent.repository';
import { MobileAiService } from '@gitroom/nestjs-libraries/mobile/ai/mobile-ai.service';
import { SubscriptionService } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/subscription.service';
import { MediaService } from '@gitroom/nestjs-libraries/database/prisma/media/media.service';
import { UploadFactory } from '@gitroom/nestjs-libraries/upload/upload.factory';
import { CheckPolicies } from '@gitroom/backend/services/auth/permissions/permissions.ability';
import {
  AuthorizationActions,
  Sections,
} from '@gitroom/backend/services/auth/permissions/permission.exception.class';

@ApiTags('Mobile AI')
@ApiBearerAuth()
@Controller('/mobile/v1/ai')
export class MobileAiController {
  private storage = UploadFactory.createStorage();

  constructor(
    private _aiConsentRepository: AiConsentRepository,
    private _mobileAiService: MobileAiService,
    private _subscriptionService: SubscriptionService,
    private _mediaService: MediaService
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

  @Get('/credits')
  @ApiOperation({ summary: 'Get remaining AI image/video generation credits' })
  getCredits(
    @GetOrgFromRequest() org: Organization,
    @Query('type') type: 'ai_images' | 'ai_videos'
  ) {
    return this._subscriptionService.checkCredits(org, type || 'ai_images');
  }

  @Post('/image')
  @CheckPolicies([AuthorizationActions.Create, Sections.AI])
  @ApiOperation({ summary: 'Generate an AI image and save it to the media library' })
  async generateImage(
    @GetOrgFromRequest() org: Organization,
    @Body() body: MobileAiImageDto
  ) {
    const total = await this._subscriptionService.checkCredits(
      org,
      'ai_images'
    );
    if (process.env.STRIPE_PUBLISHABLE_KEY && total.credits <= 0) {
      throw new HttpException({ msg: 'No credits left' }, 406);
    }

    const output =
      'data:image/png;base64,' +
      (await this._mediaService.generateImage(body.prompt, org, false));

    const file = await this.storage.uploadSimple(output);
    return this._mediaService.saveFile(org.id, file.split('/').pop(), file);
  }

  @Post('/video')
  @CheckPolicies([AuthorizationActions.Create, Sections.AI])
  @ApiOperation({ summary: 'Generate an AI video and save it to the media library' })
  async generateVideo(
    @GetOrgFromRequest() org: Organization,
    @Body() body: MobileAiVideoDto
  ) {
    return this._mediaService.generateVideo(org, body);
  }
}
