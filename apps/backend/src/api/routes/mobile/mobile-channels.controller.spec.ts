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
jest.mock('@gitroom/nestjs-libraries/redis/redis.service', () => ({
  ioRedis: { set: jest.fn() },
}));

import { MobileChannelsController } from '@gitroom/backend/api/routes/mobile/mobile-channels.controller';
import { MobileModule } from '@gitroom/backend/api/routes/mobile/mobile.module';
import { ioRedis } from '@gitroom/nestjs-libraries/redis/redis.service';
import { Disconnect } from '@gitroom/nestjs-libraries/integrations/social.abstract';

describe('MobileChannelsController', () => {
  const org = { id: 'org-1' };

  const makeController = () => {
    const integrationService = {
      getIntegrationsList: jest.fn(),
      customers: jest.fn(),
      updateOnCustomerName: jest.fn(),
      updateIntegrationGroup: jest.fn(),
      setTimes: jest.fn(),
      updateProviderSettings: jest.fn(),
      disableChannel: jest.fn(),
      enableChannel: jest.fn(),
      getPostsForChannel: jest.fn(),
      deleteChannel: jest.fn(),
      getIntegrationById: jest.fn(),
      getMentions: jest.fn(),
      insertMentions: jest.fn(),
      disconnectChannel: jest.fn(),
    };
    const integrationManager = {
      getSocialIntegration: jest.fn(),
      getAllowedSocialsIntegrations: jest.fn(),
    };
    const postService = {
      deletePost: jest.fn().mockResolvedValue(undefined),
    };
    const refreshIntegrationService = {
      refresh: jest.fn(),
    };

    const controller = new MobileChannelsController(
      integrationService as any,
      integrationManager as any,
      postService as any,
      refreshIntegrationService as any
    );

    return {
      controller,
      integrationService,
      integrationManager,
      postService,
      refreshIntegrationService,
    };
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
          limits: {
            maxCharacters: 280,
            editor: 'normal',
            media: expect.objectContaining({ maxImages: expect.any(Number) }),
          },
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
          limits: {
            maxCharacters: null,
            editor: null,
            media: expect.objectContaining({ maxImages: expect.any(Number) }),
          },
        },
      ],
    });
  });

  it('customers delegates to IntegrationService.customers(org.id)', async () => {
    const { controller, integrationService } = makeController();
    integrationService.customers.mockResolvedValue([{ customer: 'acme' }]);

    const result = await controller.getCustomers(org as any);

    expect(integrationService.customers).toHaveBeenCalledWith(org.id);
    expect(result).toEqual([{ customer: 'acme' }]);
  });

  it('updateOnCustomerName delegates with org.id, id, name', async () => {
    const { controller, integrationService } = makeController();
    integrationService.updateOnCustomerName.mockResolvedValue({ id: 'int-1' });

    const result = await controller.updateOnCustomerName(
      org as any,
      'int-1',
      { name: 'Acme Corp' }
    );

    expect(integrationService.updateOnCustomerName).toHaveBeenCalledWith(
      org.id,
      'int-1',
      'Acme Corp'
    );
    expect(result).toEqual({ id: 'int-1' });
  });

  it('updateIntegrationGroup delegates with org.id, id, group', async () => {
    const { controller, integrationService } = makeController();
    integrationService.updateIntegrationGroup.mockResolvedValue({
      id: 'int-1',
    });

    const result = await controller.updateIntegrationGroup(
      org as any,
      'int-1',
      { group: 'team-a' }
    );

    expect(integrationService.updateIntegrationGroup).toHaveBeenCalledWith(
      org.id,
      'int-1',
      'team-a'
    );
    expect(result).toEqual({ id: 'int-1' });
  });

  it('setTimes delegates with org.id, id, time body', async () => {
    const { controller, integrationService } = makeController();
    const body = { time: [{ time: 630 }] };
    integrationService.setTimes.mockResolvedValue({ id: 'int-1' });

    const result = await controller.setTimes(org as any, 'int-1', body as any);

    expect(integrationService.setTimes).toHaveBeenCalledWith(
      org.id,
      'int-1',
      body
    );
    expect(result).toEqual({ id: 'int-1' });
  });

  it('updateProviderSettings delegates with org.id, id, additionalSettings', async () => {
    const { controller, integrationService } = makeController();
    integrationService.updateProviderSettings.mockResolvedValue(undefined);

    const result = await controller.updateProviderSettings(
      org as any,
      'int-1',
      { additionalSettings: '[]' }
    );

    expect(integrationService.updateProviderSettings).toHaveBeenCalledWith(
      org.id,
      'int-1',
      '[]'
    );
    expect(result).toBeUndefined();
  });

  it('disableChannel delegates with org.id, id', async () => {
    const { controller, integrationService } = makeController();
    integrationService.disableChannel.mockResolvedValue({ id: 'int-1' });

    const result = await controller.disableChannel(org as any, 'int-1');

    expect(integrationService.disableChannel).toHaveBeenCalledWith(
      org.id,
      'int-1'
    );
    expect(result).toEqual({ id: 'int-1' });
  });

  describe('enableChannel', () => {
    it('passes pricing.FREE.channel when org has no subscription', async () => {
      const { controller, integrationService } = makeController();
      integrationService.enableChannel.mockResolvedValue({ id: 'int-1' });

      const result = await controller.enableChannel(org as any, 'int-1');

      expect(integrationService.enableChannel).toHaveBeenCalledWith(
        org.id,
        expect.any(Number),
        'int-1'
      );
      expect(result).toEqual({ id: 'int-1' });
    });

    it('passes org.subscription.totalChannels when present', async () => {
      const { controller, integrationService } = makeController();
      integrationService.enableChannel.mockResolvedValue({ id: 'int-1' });
      const orgWithSub = { id: 'org-1', subscription: { totalChannels: 12 } };

      await controller.enableChannel(orgWithSub as any, 'int-1');

      expect(integrationService.enableChannel).toHaveBeenCalledWith(
        orgWithSub.id,
        12,
        'int-1'
      );
    });
  });

  describe('deleteChannel', () => {
    it('deletes each post group then deletes the channel', async () => {
      const { controller, integrationService, postService } =
        makeController();
      integrationService.getPostsForChannel.mockResolvedValue([
        { group: 'group-1' },
        { group: 'group-2' },
      ]);
      integrationService.deleteChannel.mockResolvedValue({ id: 'int-1' });

      const result = await controller.deleteChannel(org as any, 'int-1');

      expect(integrationService.getPostsForChannel).toHaveBeenCalledWith(
        org.id,
        'int-1'
      );
      expect(postService.deletePost).toHaveBeenCalledWith(org.id, 'group-1');
      expect(postService.deletePost).toHaveBeenCalledWith(org.id, 'group-2');
      expect(integrationService.deleteChannel).toHaveBeenCalledWith(
        org.id,
        'int-1'
      );
      expect(result).toEqual({ id: 'int-1' });
    });

    it('skips post cleanup and still deletes the channel when there are no posts', async () => {
      const { controller, integrationService, postService } =
        makeController();
      integrationService.getPostsForChannel.mockResolvedValue([]);
      integrationService.deleteChannel.mockResolvedValue({ id: 'int-1' });

      await controller.deleteChannel(org as any, 'int-1');

      expect(postService.deletePost).not.toHaveBeenCalled();
      expect(integrationService.deleteChannel).toHaveBeenCalledWith(
        org.id,
        'int-1'
      );
    });
  });

  describe('functionIntegration', () => {
    it('calls provider[name] with token, data, internalId, integration', async () => {
      const { controller, integrationService, integrationManager } =
        makeController();
      const integration = {
        id: 'int-1',
        providerIdentifier: 'x',
        token: 'tok',
        internalId: 'internal-1',
      };
      integrationService.getIntegrationById.mockResolvedValue(integration);
      const customFn = jest.fn().mockResolvedValue({ ok: true });
      integrationManager.getSocialIntegration.mockReturnValue({
        customFn,
      });

      const result = await controller.functionIntegration(org as any, {
        id: 'int-1',
        name: 'customFn',
        data: { foo: 'bar' },
      } as any);

      expect(customFn).toHaveBeenCalledWith(
        'tok',
        { foo: 'bar' },
        'internal-1',
        integration
      );
      expect(result).toEqual({ ok: true });
    });

    it('disconnects the channel and returns false on Disconnect', async () => {
      const { controller, integrationService, integrationManager } =
        makeController();
      const integration = {
        id: 'int-1',
        providerIdentifier: 'x',
        token: 'tok',
        internalId: 'internal-1',
      };
      integrationService.getIntegrationById.mockResolvedValue(integration);
      integrationManager.getSocialIntegration.mockReturnValue({
        customFn: jest.fn().mockRejectedValue(new Disconnect()),
      });

      const result = await controller.functionIntegration(org as any, {
        id: 'int-1',
        name: 'customFn',
        data: {},
      } as any);

      expect(integrationService.disconnectChannel).toHaveBeenCalledWith(
        org.id,
        integration
      );
      expect(result).toBe(false);
    });

    it('throws when the function is not found on the provider', async () => {
      const { controller, integrationService, integrationManager } =
        makeController();
      integrationService.getIntegrationById.mockResolvedValue({
        id: 'int-1',
        providerIdentifier: 'x',
      });
      integrationManager.getSocialIntegration.mockReturnValue({});

      await expect(
        controller.functionIntegration(org as any, {
          id: 'int-1',
          name: 'missingFn',
          data: {},
        } as any)
      ).rejects.toThrow('Function not found');
    });
  });

  describe('mentions', () => {
    it('merges cached mentions with fresh results and caches the fresh ones', async () => {
      const { controller, integrationService, integrationManager } =
        makeController();
      const integration = {
        id: 'int-1',
        providerIdentifier: 'x',
        token: 'tok',
        internalId: 'internal-1',
      };
      integrationService.getIntegrationById.mockResolvedValue(integration);
      integrationManager.getSocialIntegration.mockReturnValue({
        mentions: jest
          .fn()
          .mockResolvedValue([
            { id: 'fresh-1', label: 'Fresh One', image: 'img' },
          ]),
      });
      integrationService.getMentions.mockResolvedValue([
        { username: 'cached-1', name: 'Cached One', image: 'img2' },
      ]);

      const result = await controller.mentions(org as any, {
        id: 'int-1',
        name: 'mentions',
        data: { query: 'foo' },
      } as any);

      expect(integrationService.insertMentions).toHaveBeenCalledWith('x', [
        { name: 'Fresh One', username: 'fresh-1', image: 'img', doNotCache: false },
      ]);
      expect(result).toEqual([
        { id: 'cached-1', image: 'img2', label: 'Cached One' },
        { id: 'fresh-1', label: 'Fresh One', image: 'img' },
      ]);
    });
  });

  describe('connect', () => {
    beforeEach(() => {
      (ioRedis.set as jest.Mock).mockClear();
      process.env.FRONTEND_URL = 'https://front.end';
    });

    it('rejects an unknown provider with 400', async () => {
      const { controller, integrationManager } = makeController();
      integrationManager.getAllowedSocialsIntegrations.mockResolvedValue([
        'x',
      ]);

      await expect(
        controller.connect('unknown', undefined as any, undefined as any, org as any)
      ).rejects.toMatchObject({
        response: { msg: 'Integration not allowed' },
        status: 400,
      });
    });

    it('generates the auth url, sets the mobile/redirect redis keys, and returns url+state', async () => {
      const { controller, integrationManager } = makeController();
      integrationManager.getAllowedSocialsIntegrations.mockResolvedValue([
        'x',
      ]);
      integrationManager.getSocialIntegration.mockReturnValue({
        generateAuthUrl: jest.fn().mockResolvedValue({
          codeVerifier: 'verifier',
          state: 'state-1',
          url: 'https://provider.example/authorize',
        }),
      });

      const result = await controller.connect(
        'x',
        undefined as any,
        undefined as any,
        org as any
      );

      expect(ioRedis.set).toHaveBeenCalledWith(
        'mobile:state-1',
        '1',
        'EX',
        3600
      );
      expect(ioRedis.set).toHaveBeenCalledWith(
        'redirect:state-1',
        'https://front.end/m/connected?provider=x',
        'EX',
        3600
      );
      expect(result).toEqual({
        url: 'https://provider.example/authorize',
        state: 'state-1',
      });
    });
  });

  it('MobileModule.prototype.configure exists', () => {
    expect(typeof MobileModule.prototype.configure).toBe('function');
  });
});
