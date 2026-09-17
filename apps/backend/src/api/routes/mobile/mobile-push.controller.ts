import { Body, Controller, Delete, Get, Param, Put, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Organization } from '@prisma/client';
import { PushService } from '@gitroom/nestjs-libraries/mobile/push/push.service';
import { GetUserFromRequest } from '@gitroom/nestjs-libraries/user/user.from.request';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import {
  MobilePushDeviceDto,
  MobilePushPrefsDto,
  MobilePushPrefsQueryDto,
} from '@gitroom/nestjs-libraries/dtos/mobile/mobile-push.dto';

@ApiTags('Mobile Push')
@ApiBearerAuth()
@Controller('/mobile/v1/push')
export class MobilePushController {
  constructor(private _pushService: PushService) {}

  @Put('/devices')
  async register(
    @GetUserFromRequest() user: any,
    @GetOrgFromRequest() org: Organization,
    @Body() body: MobilePushDeviceDto
  ) {
    return {
      device: await this._pushService.registerDevice(user.id, org?.id, body),
    };
  }

  @Delete('/devices/:token')
  async unregister(
    @GetUserFromRequest() user: any,
    @Param('token') token: string
  ) {
    return this._pushService.unregisterDevice(user.id, token);
  }

  @Get('/prefs')
  async getPrefs(
    @GetUserFromRequest() user: any,
    @Query() q: MobilePushPrefsQueryDto
  ) {
    return this._pushService.getPrefs(user.id, q.token);
  }

  @Put('/prefs')
  async setPrefs(
    @GetUserFromRequest() user: any,
    @Body() body: MobilePushPrefsDto
  ) {
    return this._pushService.setPrefs(user.id, body.apnsToken, body.prefs);
  }
}
