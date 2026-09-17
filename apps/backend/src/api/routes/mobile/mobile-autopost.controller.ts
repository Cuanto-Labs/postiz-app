import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Organization } from '@prisma/client';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import { CheckPolicies } from '@gitroom/backend/services/auth/permissions/permissions.ability';
import {
  AuthorizationActions,
  Sections,
} from '@gitroom/backend/services/auth/permissions/permission.exception.class';
import { AutopostService } from '@gitroom/nestjs-libraries/database/prisma/autopost/autopost.service';
import { AutopostDto } from '@gitroom/nestjs-libraries/dtos/autopost/autopost.dto';
import { MobileAutopostActiveDto } from '@gitroom/nestjs-libraries/dtos/mobile/mobile-autopost.dto';

@ApiTags('Mobile Autopost')
@ApiBearerAuth()
@Controller('/mobile/v1/autopost')
export class MobileAutopostController {
  constructor(private _autopostsService: AutopostService) {}

  @Get('/')
  async list(@GetOrgFromRequest() org: Organization) {
    return this._autopostsService.getAutoposts(org.id);
  }

  @Post('/')
  @CheckPolicies([AuthorizationActions.Create, Sections.WEBHOOKS])
  async create(
    @GetOrgFromRequest() org: Organization,
    @Body() body: AutopostDto
  ) {
    return this._autopostsService.createAutopost(org.id, body);
  }

  @Put('/:id')
  async update(
    @GetOrgFromRequest() org: Organization,
    @Body() body: AutopostDto,
    @Param('id') id: string
  ) {
    return this._autopostsService.createAutopost(org.id, body, id);
  }

  @Delete('/:id')
  async delete(
    @GetOrgFromRequest() org: Organization,
    @Param('id') id: string
  ) {
    return this._autopostsService.deleteAutopost(org.id, id);
  }

  @Post('/:id/active')
  async changeActive(
    @GetOrgFromRequest() org: Organization,
    @Param('id') id: string,
    @Body() body: MobileAutopostActiveDto
  ) {
    return this._autopostsService.changeActive(org.id, id, body.active);
  }
}
