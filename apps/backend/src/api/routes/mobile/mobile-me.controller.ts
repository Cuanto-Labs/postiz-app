import { Controller, Get, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import { OrganizationService } from '@gitroom/nestjs-libraries/database/prisma/organizations/organization.service';
import { PermissionsService } from '@gitroom/backend/services/auth/permissions/permissions.service';
import { GetUserFromRequest } from '@gitroom/nestjs-libraries/user/user.from.request';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';

@ApiTags('Mobile Me')
@ApiBearerAuth()
@Controller('/mobile/v1/me')
export class MobileMeController {
  constructor(
    private _organizationService: OrganizationService,
    private _permissionsService: PermissionsService
  ) {}

  @Get('/')
  @ApiOperation({
    summary: 'Get the current user, orgs, current org and plan tier + limits',
  })
  async me(
    @GetUserFromRequest() user: any,
    @GetOrgFromRequest() org: any,
    @Req() req: Request
  ) {
    const orgs = await this._organizationService.getOrgsByUserId(user.id);

    const { subscription, options } =
      await this._permissionsService.getPackageOptions(org.id);

    const tier =
      subscription?.subscriptionTier ??
      (process.env.STRIPE_PUBLISHABLE_KEY ? 'FREE' : 'PRO');

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        lastName: user.lastName,
        pictureId: user.pictureId,
        providerName: user.providerName,
        aiConsentAt: user.aiConsentAt ?? null,
      },
      org: {
        id: org.id,
        name: org.name,
        role: org.users[0].role,
      },
      orgs: orgs.map((o: any) => ({
        id: o.id,
        name: o.name,
        role: o.users[0].role,
        disabled: o.users[0].disabled,
      })),
      plan: {
        tier,
        options,
      },
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-expect-error
      sessionId: req.mobileSession?.id,
    };
  }
}
