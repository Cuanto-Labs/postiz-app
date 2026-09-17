import { Body, Controller, Delete, Get, Param, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Organization } from '@prisma/client';
import { SetsService } from '@gitroom/nestjs-libraries/database/prisma/sets/sets.service';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import { SetsDto } from '@gitroom/nestjs-libraries/dtos/sets/sets.dto';

@ApiTags('Mobile Sets')
@ApiBearerAuth()
@Controller('/mobile/v1/sets')
export class MobileSetsController {
  constructor(private _setsService: SetsService) {}

  @Get('/')
  @ApiOperation({ summary: 'List sets for the organization' })
  async getSets(@GetOrgFromRequest() org: Organization) {
    return this._setsService.getSets(org.id);
  }

  @Post('/')
  @ApiOperation({ summary: 'Create a set' })
  async createSet(
    @GetOrgFromRequest() org: Organization,
    @Body() body: SetsDto
  ) {
    return this._setsService.createSet(org.id, body);
  }

  @Put('/:id')
  @ApiOperation({ summary: 'Update a set' })
  async updateSet(
    @GetOrgFromRequest() org: Organization,
    @Body() body: SetsDto,
    @Param('id') id: string
  ) {
    return this._setsService.createSet(org.id, { ...body, id });
  }

  @Delete('/:id')
  @ApiOperation({ summary: 'Delete a set' })
  async deleteSet(
    @GetOrgFromRequest() org: Organization,
    @Param('id') id: string
  ) {
    return this._setsService.deleteSet(org.id, id);
  }
}
