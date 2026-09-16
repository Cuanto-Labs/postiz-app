import 'reflect-metadata';

// mobile.module.ts pulls in ApiModule and MobileAuthController, both of which
// transitively import the real AuthService, which pulls in nostr-tools (ESM)
// that ts-jest's CJS transform cannot require — see
// mobile-auth.controller.spec.ts for the same workaround, applied here to
// every real import MobileModule reaches since only the class reference is
// needed.
jest.mock('@gitroom/backend/api/api.module', () => ({
  ApiModule: class ApiModule {},
}));
jest.mock('@gitroom/backend/services/auth/auth.service', () => ({
  AuthService: class AuthService {},
}));
// MobileChannelsController imports these directly (not via ApiModule), and
// IntegrationManager transitively reaches nostr.provider.ts -> nostr-tools,
// an ESM package ts-jest's CJS transform cannot require. Only the class
// references are needed here, so stub them the same way.
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/integrations/integration.service',
  () => ({ IntegrationService: class IntegrationService {} })
);
jest.mock(
  '@gitroom/nestjs-libraries/integrations/integration.manager',
  () => ({ IntegrationManager: class IntegrationManager {} })
);

import { MobileChannelsController } from '@gitroom/backend/api/routes/mobile/mobile-channels.controller';
import { MobileModule } from '@gitroom/backend/api/routes/mobile/mobile.module';

describe('MobileChannelsController', () => {
  const org = { id: 'org-1' };

  const makeController = () => {
    const integrationService = {
      getIntegrationsList: jest.fn(),
    };
    const integrationManager = {
      getSocialIntegration: jest.fn(),
    };

    const controller = new MobileChannelsController(
      integrationService as any,
      integrationManager as any
    );

    return { controller, integrationService, integrationManager };
  };

  it('exposes the /mobile/v1/channels path', () => {
    expect(Reflect.getMetadata('path', MobileChannelsController)).toBe(
      '/mobile/v1/channels'
    );
  });

  it('maps integrations to channels with disabled/refreshNeeded/limits', async () => {
    const { controller, integrationService, integrationManager } =
      makeController();

    integrationService.getIntegrationsList.mockResolvedValue([
      {
        id: 'int-1',
        internalId: 'internal-1',
        name: 'My Page',
        providerIdentifier: 'x',
        picture: null,
        disabled: false,
        refreshNeeded: true,
        inBetweenSteps: false,
        profile: 'my-profile',
        type: 'social',
        customer: null,
        additionalSettings: '[]',
      },
    ]);
    integrationManager.getSocialIntegration.mockReturnValue({
      maxLength: jest.fn().mockReturnValue(280),
      editor: 'normal',
    });

    const result = await controller.list(org as any);

    expect(integrationService.getIntegrationsList).toHaveBeenCalledWith(
      org.id
    );
    expect(integrationManager.getSocialIntegration).toHaveBeenCalledWith('x');
    expect(result).toEqual({
      channels: [
        {
          id: 'int-1',
          internalId: 'internal-1',
          name: 'My Page',
          identifier: 'x',
          picture: '/no-picture.jpg',
          disabled: false,
          refreshNeeded: true,
          inBetweenSteps: false,
          display: 'my-profile',
          type: 'social',
          customer: null,
          limits: { maxCharacters: 280, editor: 'normal' },
        },
      ],
    });
  });

  it('returns null limits and never throws when the provider is missing (removed integration)', async () => {
    const { controller, integrationService, integrationManager } =
      makeController();

    integrationService.getIntegrationsList.mockResolvedValue([
      {
        id: 'int-2',
        internalId: 'internal-2',
        name: 'Old Page',
        providerIdentifier: 'removed-provider',
        picture: null,
        disabled: true,
        refreshNeeded: false,
        inBetweenSteps: false,
        profile: null,
        type: 'social',
        customer: null,
        additionalSettings: '[]',
      },
    ]);
    integrationManager.getSocialIntegration.mockReturnValue(undefined);

    const result = await controller.list(org as any);

    expect(result).toEqual({
      channels: [
        {
          id: 'int-2',
          internalId: 'internal-2',
          name: 'Old Page',
          identifier: 'removed-provider',
          picture: '/no-picture.jpg',
          disabled: true,
          refreshNeeded: false,
          inBetweenSteps: false,
          display: null,
          type: 'social',
          customer: null,
          limits: { maxCharacters: null, editor: null },
        },
      ],
    });
  });

  it('MobileModule.prototype.configure exists', () => {
    expect(typeof MobileModule.prototype.configure).toBe('function');
  });
});
