import {
  Body,
  Controller,
  Delete,
  Get,
  HttpException,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UseInterceptors,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiHeader,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { Organization } from '@prisma/client';
import { PostsService } from '@gitroom/nestjs-libraries/database/prisma/posts/posts.service';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import {
  MobileOldPostsQueryDto,
  MobilePostsQueryDto,
  MobileRescheduleDto,
} from '@gitroom/nestjs-libraries/dtos/mobile/mobile-posts.dto';
import { GetPostsDto } from '@gitroom/nestjs-libraries/dtos/posts/get.posts.dto';
import { GetPostsListDto } from '@gitroom/nestjs-libraries/dtos/posts/get.posts.list.dto';
import { CheckPolicies } from '@gitroom/backend/services/auth/permissions/permissions.ability';
import {
  AuthorizationActions,
  Sections,
} from '@gitroom/backend/services/auth/permissions/permission.exception.class';
import { PostValidationException } from '@gitroom/backend/api/routes/posts.validation.exception';
import { MobileIdempotencyInterceptor } from './mobile-idempotency.interceptor';

@ApiTags('Mobile Posts')
@ApiBearerAuth()
@Controller('/mobile/v1/posts')
export class MobilePostsController {
  constructor(private _postsService: PostsService) {}

  @Get('/')
  @ApiOperation({ summary: 'List posts within a date window' })
  async list(
    @GetOrgFromRequest() org: Organization,
    @Query() query: MobilePostsQueryDto
  ) {
    return {
      posts: await this._postsService.getPostsMinified(org.id, {
        startDate: query.from,
        endDate: query.to,
        customer: query.customer,
      } as GetPostsDto),
    };
  }

  @Get('/list')
  @ApiOperation({ summary: 'Get a paginated list of posts' })
  async listPosts(
    @GetOrgFromRequest() org: Organization,
    @Query() query: GetPostsListDto
  ) {
    return this._postsService.getPostsList(org.id, query);
  }

  @Get('/old')
  @ApiOperation({ summary: 'Get old posts before a given date' })
  async oldPosts(
    @GetOrgFromRequest() org: Organization,
    @Query() query: MobileOldPostsQueryDto
  ) {
    return this._postsService.getOldPosts(org.id, query.date);
  }

  @Get('/find-slot')
  @ApiOperation({ summary: 'Find the next free posting slot' })
  async findSlot(@GetOrgFromRequest() org: Organization) {
    return { date: await this._postsService.findFreeDateTime(org.id) };
  }

  @Get('/find-slot/:id')
  @ApiOperation({ summary: 'Find the next free posting slot for an integration' })
  async findSlotIntegration(
    @GetOrgFromRequest() org: Organization,
    @Param('id') id?: string
  ) {
    return { date: await this._postsService.findFreeDateTime(org.id, id) };
  }

  @Get('/:group')
  @ApiOperation({ summary: 'Get a post group by its group id' })
  async detail(
    @GetOrgFromRequest() org: Organization,
    @Param('group') group: string
  ) {
    const result = await this._postsService.getPostsByGroup(org.id, group);

    if (!result?.posts?.length) {
      throw new HttpException({ msg: 'Post not found' }, 404);
    }

    return result;
  }

  private async _validateAndCreate(org: Organization, rawBody: any) {
    // Server-side validation — never trust the client to have validated.
    const validation = await this._postsService.validatePosts(
      org.id,
      rawBody?.posts || []
    );

    const fail = (item: (typeof validation)[number], error: string) => {
      throw new PostValidationException({
        provider: item.identifier,
        name: item.name,
        error,
      });
    };

    for (const item of validation) {
      if (item.emptyContent) {
        fail(
          item,
          'Your post should have at least one character or one image.'
        );
      }
    }

    if (rawBody?.type !== 'draft') {
      for (const item of validation) {
        if (!item.valid) {
          fail(item, item.settingsError || 'Please fix your settings');
        }
        if (item.errors !== true) {
          fail(item, item.errors as string);
        }
        if (item.tooLong) {
          fail(item, 'post is too long, please fix it');
        }
      }
    }

    const body = await this._postsService.mapTypeToPost(rawBody, org.id);
    return this._postsService.createPost(org.id, body, 'WEB');
  }

  @Post('/')
  @UseInterceptors(MobileIdempotencyInterceptor)
  @CheckPolicies([AuthorizationActions.Create, Sections.POSTS_PER_MONTH])
  @ApiOperation({ summary: 'Create a post' })
  @ApiHeader({ name: 'Idempotency-Key', required: false })
  async create(@GetOrgFromRequest() org: Organization, @Body() rawBody: any) {
    return this._validateAndCreate(org, rawBody);
  }

  @Put('/:group')
  @UseInterceptors(MobileIdempotencyInterceptor)
  @CheckPolicies([AuthorizationActions.Create, Sections.POSTS_PER_MONTH])
  @ApiOperation({ summary: 'Update a post group' })
  @ApiHeader({ name: 'Idempotency-Key', required: false })
  async update(
    @GetOrgFromRequest() org: Organization,
    @Param('group') group: string,
    @Body() rawBody: any
  ) {
    if (rawBody?.posts) {
      for (const post of rawBody.posts) {
        post.group = group;
      }
    }
    rawBody.type = rawBody?.type ?? 'update';

    return this._validateAndCreate(org, rawBody);
  }

  @Patch('/:group/date')
  @ApiOperation({ summary: 'Reschedule every root post in a group' })
  async reschedule(
    @GetOrgFromRequest() org: Organization,
    @Param('group') group: string,
    @Body() body: MobileRescheduleDto
  ) {
    const result = await this._postsService.getPostsByGroup(org.id, group);

    if (!result?.posts?.length) {
      throw new HttpException({ msg: 'Post not found' }, 404);
    }

    for (const post of result.posts) {
      if (!post.parentPostId) {
        await this._postsService.changeDate(
          org.id,
          post.id,
          body.date,
          body.action ?? 'update',
          false
        );
      }
    }

    return { group, date: body.date };
  }

  @Delete('/:group')
  @ApiOperation({ summary: 'Delete a post group' })
  async remove(
    @GetOrgFromRequest() org: Organization,
    @Param('group') group: string
  ) {
    await this._postsService.deletePost(org.id, group);
    return { ok: true };
  }
}
