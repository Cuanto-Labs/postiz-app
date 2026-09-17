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

import { MobileAiController } from '@gitroom/backend/api/routes/mobile/mobile-ai.controller';
import { MobileModule } from '@gitroom/backend/api/routes/mobile/mobile.module';
import { CHECK_POLICIES_KEY } from '@gitroom/backend/services/auth/permissions/permissions.ability';
import {
  AuthorizationActions,
  Sections,
} from '@gitroom/backend/services/auth/permissions/permission.exception.class';

describe('MobileAiController', () => {
  const user = { id: 'user-1' };

  const makeController = () => {
    const aiConsentRepository = {
      getConsentAt: jest.fn(),
      setConsent: jest.fn(),
    };
    const mobileAiService = {
      suggest: jest.fn(),
    };

    const controller = new MobileAiController(
      aiConsentRepository as any,
      mobileAiService as any
    );

    return { controller, aiConsentRepository, mobileAiService };
  };

  it('exposes the /mobile/v1/ai path', () => {
    expect(Reflect.getMetadata('path', MobileAiController)).toBe(
      '/mobile/v1/ai'
    );
  });

  it('GET /consent returns the current consent timestamp', async () => {
    const { controller, aiConsentRepository } = makeController();
    const now = new Date('2026-01-01T00:00:00.000Z');
    aiConsentRepository.getConsentAt.mockResolvedValue(now);

    const result = await controller.getConsent(user as any);

    expect(aiConsentRepository.getConsentAt).toHaveBeenCalledWith(user.id);
    expect(result).toEqual({ aiConsentAt: now });
  });

  it('POST /consent delegates to setConsent and returns the new timestamp', async () => {
    const { controller, aiConsentRepository } = makeController();
    const now = new Date('2026-01-01T00:00:00.000Z');
    aiConsentRepository.setConsent.mockResolvedValue({ aiConsentAt: now });

    const result = await controller.setConsent(user as any, {
      granted: true,
    });

    expect(aiConsentRepository.setConsent).toHaveBeenCalledWith(
      user.id,
      true
    );
    expect(result).toEqual({ aiConsentAt: now });
  });

  it('POST /suggest delegates to MobileAiService.suggest', async () => {
    const { controller, mobileAiService } = makeController();
    mobileAiService.suggest.mockResolvedValue({ suggestions: ['a'] });

    const body = { content: 'hello', mode: 'variations' as const };
    const result = await controller.suggest(user as any, body as any);

    expect(mobileAiService.suggest).toHaveBeenCalledWith(user.id, body);
    expect(result).toEqual({ suggestions: ['a'] });
  });

  it('marks /suggest with the Sections.AI policy', () => {
    const metadata = Reflect.getMetadata(
      CHECK_POLICIES_KEY,
      MobileAiController.prototype.suggest
    );

    expect(metadata).toEqual([[AuthorizationActions.Create, Sections.AI]]);
  });

  it('MobileModule.prototype.configure exists', () => {
    expect(typeof MobileModule.prototype.configure).toBe('function');
  });
});
