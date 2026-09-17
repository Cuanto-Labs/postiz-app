import 'reflect-metadata';

// PermissionsService transitively pulls in IntegrationManager -> the nostr
// provider, which ships ESM and cannot be required under ts-jest's CJS
// transform. The controller only needs the class reference for Nest's
// design:paramtypes metadata; every method is mocked below, so a lightweight
// stand-in avoids the ESM import entirely (same pattern as
// mobile-devices.controller.spec.ts / mobile-auth.controller.spec.ts).
jest.mock(
  '@gitroom/backend/services/auth/permissions/permissions.service',
  () => ({
    PermissionsService: class PermissionsService {},
  })
);

import { MobileMeController } from '@gitroom/backend/api/routes/mobile/mobile-me.controller';

describe('MobileMeController', () => {
  const user = {
    id: 'user-1',
    email: 'user@example.com',
    name: 'User',
    lastName: 'One',
    pictureId: 'pic-1',
    providerName: 'LOCAL',
    password: 'should-never-be-returned',
  };

  const org = {
    id: 'org-1',
    name: 'Org One',
    users: [{ role: 'ADMIN', disabled: false }],
  };

  const makeController = () => {
    const organizationService = {
      getOrgsByUserId: jest.fn().mockResolvedValue([
        org,
        { id: 'org-2', name: 'Org Two', users: [{ role: 'USER', disabled: true }] },
      ]),
    };
    const permissionsService = {
      getPackageOptions: jest.fn().mockResolvedValue({
        subscription: { subscriptionTier: 'STANDARD' },
        options: { channel: 5 },
      }),
    };

    const controller = new MobileMeController(
      organizationService as any,
      permissionsService as any
    );

    return { controller, organizationService, permissionsService };
  };

  it('exposes the /mobile/v1/me path', () => {
    expect(Reflect.getMetadata('path', MobileMeController)).toBe(
      '/mobile/v1/me'
    );
  });

  it('returns user, org, orgs and plan without leaking password', async () => {
    const { controller, permissionsService } = makeController();
    const req = { mobileSession: { id: 'session-1' } };

    const result = await controller.me(user as any, org as any, req as any);

    expect(permissionsService.getPackageOptions).toHaveBeenCalledWith(
      'org-1'
    );
    expect(result).toEqual({
      user: {
        id: 'user-1',
        email: 'user@example.com',
        name: 'User',
        lastName: 'One',
        pictureId: 'pic-1',
        providerName: 'LOCAL',
        aiConsentAt: null,
      },
      org: {
        id: 'org-1',
        name: 'Org One',
        role: 'ADMIN',
      },
      orgs: [
        { id: 'org-1', name: 'Org One', role: 'ADMIN', disabled: false },
        { id: 'org-2', name: 'Org Two', role: 'USER', disabled: true },
      ],
      plan: {
        tier: 'STANDARD',
        options: { channel: 5 },
      },
      sessionId: 'session-1',
    });
    expect(result).not.toHaveProperty('user.password');
    expect(JSON.stringify(result)).not.toContain('password');
  });

  it('falls back to FREE/PRO tier when there is no subscription', async () => {
    const { controller, permissionsService } = makeController();
    permissionsService.getPackageOptions.mockResolvedValue({
      subscription: null,
      options: {},
    });
    const req = {};

    const result = await controller.me(user as any, org as any, req as any);

    const expectedTier = process.env.STRIPE_PUBLISHABLE_KEY ? 'FREE' : 'PRO';
    expect(result.plan.tier).toBe(expectedTier);
    expect(result.sessionId).toBeUndefined();
  });

  it('returns aiConsentAt when the user has consented', async () => {
    const { controller } = makeController();
    const consentedUser = { ...user, aiConsentAt: new Date('2026-01-01') };
    const req = {};

    const result = await controller.me(consentedUser as any, org as any, req as any);

    expect(result.user.aiConsentAt).toEqual(new Date('2026-01-01'));
  });
});
