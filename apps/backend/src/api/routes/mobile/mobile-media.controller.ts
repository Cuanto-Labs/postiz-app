import {
  Body,
  Controller,
  Get,
  HttpException,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Organization } from '@prisma/client';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import { MediaService } from '@gitroom/nestjs-libraries/database/prisma/media/media.service';
import { MobileMediaUploadService } from '@gitroom/nestjs-libraries/mobile/media/mobile-media-upload.service';
import {
  MobileMediaAbortUploadDto,
  MobileMediaCompleteUploadDto,
  MobileMediaCreateUploadDto,
  MobileMediaListQueryDto,
} from '@gitroom/nestjs-libraries/dtos/mobile/mobile-media.dto';

@ApiTags('Mobile Media')
@ApiBearerAuth()
@Controller('/mobile/v1/media')
export class MobileMediaController {
  constructor(
    private _mobileMediaUploadService: MobileMediaUploadService,
    private _mediaService: MediaService
  ) {}

  @Post('/uploads')
  @ApiOperation({ summary: 'Create a presigned multipart upload' })
  async createUpload(@Body() body: MobileMediaCreateUploadDto) {
    return this._mobileMediaUploadService.createUpload(body);
  }

  @Post('/uploads/complete')
  @ApiOperation({ summary: 'Complete a presigned multipart upload' })
  async completeUpload(
    @GetOrgFromRequest() org: Organization,
    @Body() body: MobileMediaCompleteUploadDto
  ) {
    const { key, location } = await this._mobileMediaUploadService.completeUpload(
      body
    );

    const media = (await this._mediaService.saveUploadedFile(
      org.id,
      key,
      location,
      body.originalName ?? key
    )) as Awaited<
      ReturnType<typeof this._mediaService.saveUploadedFile>
    > & { processingError?: string | null };

    return {
      media: {
        id: media.id,
        name: media.name,
        path: media.path,
        status: media.status,
        processingError: media.processingError ?? null,
        thumbnail: media.thumbnail,
      },
    };
  }

  @Post('/uploads/abort')
  @ApiOperation({ summary: 'Abort a presigned multipart upload' })
  async abortUpload(@Body() body: MobileMediaAbortUploadDto) {
    await this._mobileMediaUploadService.abortUpload(body);
    return { ok: true };
  }

  @Get('/:id/status')
  @ApiOperation({ summary: 'Get processing status for a media item' })
  async status(
    @GetOrgFromRequest() org: Organization,
    @Param('id') id: string
  ) {
    const media = await this._mediaService.getMediaStatus(org.id, id);

    if (!media) {
      throw new HttpException({ msg: 'Media not found' }, 404);
    }

    return media;
  }

  @Get('/')
  @ApiOperation({ summary: 'List media' })
  async list(
    @GetOrgFromRequest() org: Organization,
    @Query() query: MobileMediaListQueryDto
  ) {
    return this._mediaService.getMedia(org.id, query.page as number);
  }
}
