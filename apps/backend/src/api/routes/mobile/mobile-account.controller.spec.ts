import 'reflect-metadata';

// mobile.module.ts pulls in ApiModule and MobileAuthController, both of which
// transitively import the real AuthService, which pulls in nostr-tools (ESM)
// that ts-jest's CJS transform cannot require — see
// mobile-auth.controller.spec.ts for the same workaround, applied here to
// every real import MobileModule reaches since only the class reference is
// needed. (reused from mobile-push.controller.spec.ts)
jest.mock('@gitroom/backend/api/api.module', () => ({
  ApiModule: class ApiModule {},
}));
jest.mock('@gitroom/backend/services/auth/auth.service', () => ({
  AuthService: class AuthService {},
}));
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/integrations/integration.service',
  () => ({ IntegrationService: class IntegrationService {} })
);
jest.mock(
  '@gitroom/nestjs-libraries/integrations/integration.manager',
  () => ({ IntegrationManager: class IntegrationManager {} })
);
jest.mock(
  '@gitroom/backend/services/auth/permissions/permissions.service',
  () => ({ PermissionsService: class PermissionsService {} })
);
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/posts/posts.service',
  () => ({ PostsService: class PostsService {} })
);
// MobileAccountService (pulled in by mobile.module.ts) transitively reaches
// nestjs-temporal-core, the Stripe/Email services and org/integration
// repositories — stub the class references the same way
// mobile-account.service.spec.ts does.
jest.mock('nestjs-temporal-core', () => ({
  TemporalService: class TemporalService {},
}));
jest.mock('@gitroom/nestjs-libraries/services/email.service', () => ({
  EmailService: class EmailService {},
}));
jest.mock('@gitroom/nestjs-libraries/services/stripe.service', () => ({
  StripeService: class StripeService {},
}));
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/organizations/organization.repository',
  () => ({
    OrganizationRepository: class OrganizationRepository {},
  })
);
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/integrations/integration.repository',
  () => ({
    IntegrationRepository: class IntegrationRepository {},
  })
);
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/subscriptions/subscription.service',
  () => ({
    SubscriptionService: class SubscriptionService {},
  })
);

import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { MobileAccountController } from '@gitroom/backend/api/routes/mobile/mobile-account.controller';
import { MobileDeleteAccountDto } from '@gitroom/nestjs-libraries/dtos/mobile/mobile-account.dto';
import { MobileModule } from '@gitroom/backend/api/routes/mobile/mobile.module';

describe('MobileAccountController', () => {
  const user = { id: 'user-1', email: 'user@example.com' };

  const makeController = () => {
    const mobileAccountService = {
      preview: jest.fn().mockResolvedValue({
        orgsToDelete: [{ id: 'org-1', name: 'Org 1' }],
        orgsToLeave: [{ id: 'org-2', name: 'Org 2' }],
      }),
      deleteAccount: jest.fn().mockResolvedValue({
        deletedOrgs: [{ id: 'org-1', name: 'Org 1' }],
        leftOrgs: [{ id: 'org-2', name: 'Org 2' }],
      }),
    };

    const controller = new MobileAccountController(
      mobileAccountService as any
    );

    return { controller, mobileAccountService };
  };

  it('exposes the /mobile/v1/account path', () => {
    expect(Reflect.getMetadata('path', MobileAccountController)).toBe(
      '/mobile/v1/account'
    );
  });

  it('deletionPreview delegates to MobileAccountService.preview(user.id)', async () => {
    const { controller, mobileAccountService } = makeController();

    const result = await controller.deletionPreview(user as any);

    expect(mobileAccountService.preview).toHaveBeenCalledWith(user.id);
    expect(result).toEqual({
      orgsToDelete: [{ id: 'org-1', name: 'Org 1' }],
      orgsToLeave: [{ id: 'org-2', name: 'Org 2' }],
    });
  });

  it('deleteAccount calls deleteAccount(user.id, user.email) and returns { ok, deletedOrgs, leftOrgs }', async () => {
    const { controller, mobileAccountService } = makeController();

    const result = await controller.deleteAccount(user as any, {
      confirm: 'DELETE',
    } as MobileDeleteAccountDto);

    expect(mobileAccountService.deleteAccount).toHaveBeenCalledWith(
      user.id,
      user.email
    );
    expect(result).toEqual({
      ok: true,
      deletedOrgs: [{ id: 'org-1', name: 'Org 1' }],
      leftOrgs: [{ id: 'org-2', name: 'Org 2' }],
    });
  });

  it('MobileDeleteAccountDto rejects a wrong confirm value (ValidationPipe 400)', async () => {
    const dto = plainToInstance(MobileDeleteAccountDto, {
      confirm: 'not-delete',
    });
    const errors = await validate(dto);

    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].property).toBe('confirm');
  });

  it('MobileDeleteAccountDto accepts confirm: "DELETE"', async () => {
    const dto = plainToInstance(MobileDeleteAccountDto, {
      confirm: 'DELETE',
    });
    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('MobileModule wires MobileAccountController + MobileAccountService', async () => {
    const { MobileAccountController: RealController } = await import(
      '@gitroom/backend/api/routes/mobile/mobile-account.controller'
    );
    const { MobileAccountService } = await import(
      '@gitroom/nestjs-libraries/mobile/account/mobile-account.service'
    );

    const controllers = Reflect.getMetadata(
      'controllers',
      MobileModule
    ) as unknown[];
    const providers = Reflect.getMetadata(
      'providers',
      MobileModule
    ) as unknown[];

    expect(controllers).toContain(RealController);
    expect(providers).toContain(MobileAccountService);
  });
});
