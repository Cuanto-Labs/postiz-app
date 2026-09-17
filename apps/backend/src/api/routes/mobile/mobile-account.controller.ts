import { Body, Controller, Delete, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { MobileAccountService } from '@gitroom/nestjs-libraries/mobile/account/mobile-account.service';
import { MobileDeleteAccountDto } from '@gitroom/nestjs-libraries/dtos/mobile/mobile-account.dto';
import { GetUserFromRequest } from '@gitroom/nestjs-libraries/user/user.from.request';

@ApiTags('Mobile Account')
@ApiBearerAuth()
@Controller('/mobile/v1/account')
export class MobileAccountController {
  constructor(private _mobileAccountService: MobileAccountService) {}

  @Get('/deletion-preview')
  @ApiOperation({
    summary: 'Preview which orgs will be deleted vs left on account deletion',
  })
  async deletionPreview(@GetUserFromRequest() user: any) {
    return this._mobileAccountService.preview(user.id);
  }

  @Delete('/')
  @ApiOperation({ summary: 'Delete the current user account' })
  @Throttle({ default: { limit: 3, ttl: 60000 } })
  async deleteAccount(
    @GetUserFromRequest() user: any,
    @Body() body: MobileDeleteAccountDto
  ) {
    const { deletedOrgs, leftOrgs } =
      await this._mobileAccountService.deleteAccount(user.id, user.email);
    return { ok: true, deletedOrgs, leftOrgs };
  }
}
