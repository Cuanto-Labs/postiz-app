import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Organization } from '@prisma/client';
import { IntegrationService } from '@gitroom/nestjs-libraries/database/prisma/integrations/integration.service';
import { PostsService } from '@gitroom/nestjs-libraries/database/prisma/posts/posts.service';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import { MobileAnalyticsQueryDto } from '@gitroom/nestjs-libraries/dtos/mobile/mobile-analytics.dto';

@ApiTags('Mobile Analytics')
@ApiBearerAuth()
@Controller('/mobile/v1/analytics')
export class MobileAnalyticsController {
  constructor(
    private _integrationService: IntegrationService,
    private _postsService: PostsService
  ) {}

  @Get('/channel/:integration')
  @ApiOperation({ summary: 'Get analytics for a channel' })
  async getIntegration(
    @GetOrgFromRequest() org: Organization,
    @Param('integration') integration: string,
    @Query() query: MobileAnalyticsQueryDto
  ) {
    return this._integrationService.checkAnalytics(
      org,
      integration,
      query.date
    );
  }

  @Get('/post/:postId')
  @ApiOperation({ summary: 'Get analytics for a post' })
  async getPostAnalytics(
    @GetOrgFromRequest() org: Organization,
    @Param('postId') postId: string,
    @Query() query: MobileAnalyticsQueryDto
  ) {
    return this._postsService.checkPostAnalytics(
      org.id,
      postId,
      +query.date
    );
  }
}
