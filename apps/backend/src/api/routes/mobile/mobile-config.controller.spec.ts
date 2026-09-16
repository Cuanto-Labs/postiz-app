import 'reflect-metadata';

// IntegrationManager transitively imports nostr.provider -> nostr-tools (ESM),
// which ts-jest's CJS transform cannot require. Only the class reference is
// needed for Nest's design:paramtypes metadata; every method is mocked below,
// so a lightweight stand-in avoids the ESM import entirely (same pattern as
// mobile-auth.controller.spec.ts).
jest.mock('@gitroom/nestjs-libraries/integrations/integration.manager', () => ({
  IntegrationManager: class IntegrationManager {},
}));

import { MobileConfigController } from '@gitroom/backend/api/routes/mobile/mobile-config.controller';

describe('MobileConfigController', () => {
  const originalEnv = { ...process.env };

  afterEach(() => {
    process.env = { ...originalEnv };
  });

  const makeController = (
    providers = [
      { identifier: 'x', name: 'X' },
      { identifier: 'hidden-one', name: 'Hidden' },
    ],
    hidden: string[] = ['hidden-one']
  ) => {
    const integrationManager = {
      getAllIntegrations: jest
        .fn()
        .mockResolvedValue({ social: providers, article: [] }),
      isHiddenProvider: jest
        .fn()
        .mockImplementation((identifier: string) => hidden.includes(identifier)),
    };

    const controller = new MobileConfigController(integrationManager as any);

    return { controller, integrationManager };
  };

  it('exposes the /mobile/v1/config path', () => {
    expect(Reflect.getMetadata('path', MobileConfigController)).toBe(
      '/mobile/v1/config'
    );
  });

  it('returns MOBILE_MIN_APP_VERSION when set', async () => {
    process.env.MOBILE_MIN_APP_VERSION = '2.3.0';
    const { controller } = makeController();

    const result = await controller.config();

    expect(result.minVersion).toBe('2.3.0');
  });

  it('defaults minVersion to 1.0.0 when unset', async () => {
    delete process.env.MOBILE_MIN_APP_VERSION;
    const { controller } = makeController();

    const result = await controller.config();

    expect(result.minVersion).toBe('1.0.0');
  });

  it('filters hidden providers and maps identifier/name only', async () => {
    const { controller } = makeController();

    const result = await controller.config();

    expect(result.providers).toEqual([{ identifier: 'x', name: 'X' }]);
  });

  it('defaults links when env vars are unset', async () => {
    delete process.env.MOBILE_SUPPORT_URL;
    delete process.env.MOBILE_TERMS_URL;
    delete process.env.MOBILE_PRIVACY_URL;
    const { controller } = makeController();

    const result = await controller.config();

    expect(result.links).toEqual({
      support: 'https://socials.cuantolabs.com/support',
      terms: 'https://socials.cuantolabs.com/terms',
      privacy: 'https://socials.cuantolabs.com/privacy',
    });
  });

  it('uses env overrides for links when set', async () => {
    process.env.MOBILE_SUPPORT_URL = 'https://example.com/support';
    process.env.MOBILE_TERMS_URL = 'https://example.com/terms';
    process.env.MOBILE_PRIVACY_URL = 'https://example.com/privacy';
    const { controller } = makeController();

    const result = await controller.config();

    expect(result.links).toEqual({
      support: 'https://example.com/support',
      terms: 'https://example.com/terms',
      privacy: 'https://example.com/privacy',
    });
  });
});
