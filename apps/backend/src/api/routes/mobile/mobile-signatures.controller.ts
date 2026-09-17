import { Body, Controller, Delete, Get, Param, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Organization } from '@prisma/client';
import { SignatureService } from '@gitroom/nestjs-libraries/database/prisma/signatures/signature.service';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import { SignatureDto } from '@gitroom/nestjs-libraries/dtos/signature/signature.dto';

@ApiTags('Mobile Signatures')
@ApiBearerAuth()
@Controller('/mobile/v1/signatures')
export class MobileSignaturesController {
  constructor(private _signatureService: SignatureService) {}

  @Get('/')
  @ApiOperation({ summary: 'List signatures for the organization' })
  async getSignatures(@GetOrgFromRequest() org: Organization) {
    return this._signatureService.getSignaturesByOrgId(org.id);
  }

  @Get('/default')
  @ApiOperation({ summary: 'Get the default signature' })
  async getDefaultSignature(@GetOrgFromRequest() org: Organization) {
    return (await this._signatureService.getDefaultSignature(org.id)) || {};
  }

  @Post('/')
  @ApiOperation({ summary: 'Create a signature' })
  async createSignature(
    @GetOrgFromRequest() org: Organization,
    @Body() body: SignatureDto
  ) {
    return this._signatureService.createOrUpdateSignature(org.id, body);
  }

  @Put('/:id')
  @ApiOperation({ summary: 'Update a signature' })
  async updateSignature(
    @GetOrgFromRequest() org: Organization,
    @Body() body: SignatureDto,
    @Param('id') id: string
  ) {
    return this._signatureService.createOrUpdateSignature(org.id, body, id);
  }

  @Delete('/:id')
  @ApiOperation({ summary: 'Delete a signature' })
  async deleteSignature(
    @GetOrgFromRequest() org: Organization,
    @Param('id') id: string
  ) {
    return this._signatureService.deleteSignature(org.id, id);
  }
}
