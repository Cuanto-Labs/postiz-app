import { Body, Controller, Get, Param, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Organization } from '@prisma/client';
import { IntegrationService } from '@gitroom/nestjs-libraries/database/prisma/integrations/integration.service';
import { IntegrationManager } from '@gitroom/nestjs-libraries/integrations/integration.manager';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import { PlugDto } from '@gitroom/nestjs-libraries/dtos/plugs/plug.dto';
import { MobilePlugActivateDto } from '@gitroom/nestjs-libraries/dtos/mobile/mobile-plugs.dto';

@ApiTags('Mobile Plugs')
@ApiBearerAuth()
@Controller('/mobile/v1/plugs')
export class MobilePlugsController {
  constructor(
    private _integrationService: IntegrationService,
    private _integrationManager: IntegrationManager
  ) {}

  @Get('/')
  @ApiOperation({ summary: 'List the plug catalogue' })
  async list() {
    return { plugs: this._integrationManager.getAllPlugs() };
  }

  @Get('/channel/:id')
  @ApiOperation({ summary: 'List plugs configured for a channel' })
  async getByChannel(
    @Param('id') id: string,
    @GetOrgFromRequest() org: Organization
  ) {
    return this._integrationService.getPlugsByIntegrationId(org.id, id);
  }

  @Post('/channel/:id')
  @ApiOperation({ summary: 'Create or update a plug for a channel' })
  async createOrUpdate(
    @Param('id') id: string,
    @GetOrgFromRequest() org: Organization,
    @Body() body: PlugDto
  ) {
    return this._integrationService.createOrUpdatePlug(org.id, id, body);
  }

  @Put('/:id/activate')
  @ApiOperation({ summary: 'Activate or deactivate a plug' })
  async activate(
    @Param('id') id: string,
    @GetOrgFromRequest() org: Organization,
    @Body() body: MobilePlugActivateDto
  ) {
    return this._integrationService.changePlugActivation(
      org.id,
      id,
      body.status
    );
  }
}
