import 'reflect-metadata';

import { MobileOrgController } from '@gitroom/backend/api/routes/mobile/mobile-org.controller';
import { CHECK_POLICIES_KEY } from '@gitroom/backend/services/auth/permissions/permissions.ability';
import {
  AuthorizationActions,
  Sections,
} from '@gitroom/backend/services/auth/permissions/permission.exception.class';

describe('MobileOrgController', () => {
  const org = { id: 'org-1' };
  const user = { id: 'user-1' };

  const makeController = () => {
    const organizationService = {
      getTeam: jest.fn(),
      inviteTeamMember: jest.fn(),
      deleteTeamMember: jest.fn(),
      getShortlinkPreference: jest.fn(),
      updateShortlinkPreference: jest.fn(),
    };
    const webhooksService = {
      getWebhooks: jest.fn(),
    };

    const controller = new MobileOrgController(
      organizationService as any,
      webhooksService as any
    );

    return { controller, organizationService, webhooksService };
  };

  it('exposes the /mobile/v1/org path', () => {
    expect(Reflect.getMetadata('path', MobileOrgController)).toBe(
      '/mobile/v1/org'
    );
  });

  it('getTeam delegates to organizationService.getTeam', async () => {
    const { controller, organizationService } = makeController();
    organizationService.getTeam.mockResolvedValue([{ id: 'member-1' }]);

    const result = await controller.getTeam(org as any);

    expect(organizationService.getTeam).toHaveBeenCalledWith('org-1');
    expect(result).toEqual([{ id: 'member-1' }]);
  });

  it('inviteTeamMember delegates to organizationService.inviteTeamMember', async () => {
    const { controller, organizationService } = makeController();
    const body = { email: 'a@b.com', role: 'USER', sendEmail: true };
    organizationService.inviteTeamMember.mockResolvedValue({ id: 'invite-1' });

    const result = await controller.inviteTeamMember(
      org as any,
      user as any,
      body as any
    );

    expect(organizationService.inviteTeamMember).toHaveBeenCalledWith(
      org,
      user,
      body
    );
    expect(result).toEqual({ id: 'invite-1' });
  });

  it('deleteTeamMember delegates to organizationService.deleteTeamMember', () => {
    const { controller, organizationService } = makeController();
    organizationService.deleteTeamMember.mockResolvedValue(undefined);

    controller.deleteTeamMember(org as any, 'member-1');

    expect(organizationService.deleteTeamMember).toHaveBeenCalledWith(
      org,
      'member-1'
    );
  });

  it('getShortlinkPreference delegates to organizationService.getShortlinkPreference', async () => {
    const { controller, organizationService } = makeController();
    organizationService.getShortlinkPreference.mockResolvedValue({
      shortlink: 'SHORT',
    });

    const result = await controller.getShortlinkPreference(org as any);

    expect(
      organizationService.getShortlinkPreference
    ).toHaveBeenCalledWith('org-1');
    expect(result).toEqual({ shortlink: 'SHORT' });
  });

  it('updateShortlinkPreference delegates to organizationService.updateShortlinkPreference', async () => {
    const { controller, organizationService } = makeController();
    const body = { shortlink: 'NONE' };
    organizationService.updateShortlinkPreference.mockResolvedValue({
      shortlink: 'NONE',
    });

    const result = await controller.updateShortlinkPreference(
      org as any,
      body as any
    );

    expect(
      organizationService.updateShortlinkPreference
    ).toHaveBeenCalledWith('org-1', 'NONE');
    expect(result).toEqual({ shortlink: 'NONE' });
  });

  it('getWebhooks delegates to webhooksService.getWebhooks', async () => {
    const { controller, webhooksService } = makeController();
    webhooksService.getWebhooks.mockResolvedValue([{ id: 'webhook-1' }]);

    const result = await controller.getWebhooks(org as any);

    expect(webhooksService.getWebhooks).toHaveBeenCalledWith('org-1');
    expect(result).toEqual([{ id: 'webhook-1' }]);
  });

  it('team routes require TEAM_MEMBERS or ADMIN policies', () => {
    const { controller } = makeController();
    const expected = [
      [AuthorizationActions.Create, Sections.TEAM_MEMBERS],
      [AuthorizationActions.Create, Sections.ADMIN],
    ];

    expect(
      Reflect.getMetadata(CHECK_POLICIES_KEY, controller.getTeam)
    ).toEqual(expected);
    expect(
      Reflect.getMetadata(CHECK_POLICIES_KEY, controller.inviteTeamMember)
    ).toEqual(expected);
    expect(
      Reflect.getMetadata(CHECK_POLICIES_KEY, controller.deleteTeamMember)
    ).toEqual(expected);
  });

  it('updateShortlinkPreference requires the ADMIN policy', () => {
    const { controller } = makeController();

    expect(
      Reflect.getMetadata(
        CHECK_POLICIES_KEY,
        controller.updateShortlinkPreference
      )
    ).toEqual([[AuthorizationActions.Create, Sections.ADMIN]]);
  });
});
