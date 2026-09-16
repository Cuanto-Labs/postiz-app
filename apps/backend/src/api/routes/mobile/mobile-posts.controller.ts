import { Controller, Get, HttpException, Param, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Organization } from '@prisma/client';
import { PostsService } from '@gitroom/nestjs-libraries/database/prisma/posts/posts.service';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import { MobilePostsQueryDto } from '@gitroom/nestjs-libraries/dtos/mobile/mobile-posts.dto';
import { GetPostsDto } from '@gitroom/nestjs-libraries/dtos/posts/get.posts.dto';

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
}
