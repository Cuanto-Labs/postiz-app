import { Controller, Delete, Get, Param, Req } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import { MobileAuthService } from '@gitroom/nestjs-libraries/mobile/mobile-auth.service';
import { GetUserFromRequest } from '@gitroom/nestjs-libraries/user/user.from.request';

@ApiTags('Mobile Devices')
@Controller('/mobile/v1/devices')
export class MobileDevicesController {
  constructor(private _mobileAuthService: MobileAuthService) {}

  @Get('/')
  async list(@GetUserFromRequest() user: any, @Req() req: Request) {
    const devices = await this._mobileAuthService.listDevices(
      user.id,
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-expect-error
      req.mobileSession?.id
    );
    return { devices };
  }

  @Delete('/:id')
  async revoke(@GetUserFromRequest() user: any, @Param('id') id: string) {
    await this._mobileAuthService.revokeDevice(user.id, id);
    return { ok: true };
  }
}
