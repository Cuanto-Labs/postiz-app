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

import { MobileSignaturesController } from '@gitroom/backend/api/routes/mobile/mobile-signatures.controller';
import { MobileModule } from '@gitroom/backend/api/routes/mobile/mobile.module';

describe('MobileSignaturesController', () => {
  const org = { id: 'org-1' };

  const makeController = () => {
    const signatureService = {
      getSignaturesByOrgId: jest.fn(),
      getDefaultSignature: jest.fn(),
      createOrUpdateSignature: jest.fn(),
      deleteSignature: jest.fn(),
    };

    const controller = new MobileSignaturesController(signatureService as any);

    return { controller, signatureService };
  };

  it('exposes the /mobile/v1/signatures path', () => {
    expect(Reflect.getMetadata('path', MobileSignaturesController)).toBe(
      '/mobile/v1/signatures'
    );
  });

  it('getSignatures delegates to SignatureService.getSignaturesByOrgId', async () => {
    const { controller, signatureService } = makeController();
    signatureService.getSignaturesByOrgId.mockResolvedValue([
      { id: 'sig-1', content: 'a' },
    ]);

    const result = await controller.getSignatures(org as any);

    expect(signatureService.getSignaturesByOrgId).toHaveBeenCalledWith(
      org.id
    );
    expect(result).toEqual([{ id: 'sig-1', content: 'a' }]);
  });

  it('getDefaultSignature delegates to SignatureService.getDefaultSignature', async () => {
    const { controller, signatureService } = makeController();
    signatureService.getDefaultSignature.mockResolvedValue({
      id: 'sig-1',
      content: 'a',
    });

    const result = await controller.getDefaultSignature(org as any);

    expect(signatureService.getDefaultSignature).toHaveBeenCalledWith(org.id);
    expect(result).toEqual({ id: 'sig-1', content: 'a' });
  });

  it('getDefaultSignature falls back to an empty object', async () => {
    const { controller, signatureService } = makeController();
    signatureService.getDefaultSignature.mockResolvedValue(null);

    const result = await controller.getDefaultSignature(org as any);

    expect(result).toEqual({});
  });

  it('createSignature delegates to SignatureService.createOrUpdateSignature', async () => {
    const { controller, signatureService } = makeController();
    const body = { content: 'a', autoAdd: true };
    signatureService.createOrUpdateSignature.mockResolvedValue({
      id: 'sig-1',
      ...body,
    });

    const result = await controller.createSignature(org as any, body as any);

    expect(signatureService.createOrUpdateSignature).toHaveBeenCalledWith(
      org.id,
      body
    );
    expect(result).toEqual({ id: 'sig-1', ...body });
  });

  it('updateSignature delegates to SignatureService.createOrUpdateSignature with an id', async () => {
    const { controller, signatureService } = makeController();
    const body = { content: 'b', autoAdd: false };
    signatureService.createOrUpdateSignature.mockResolvedValue({
      id: 'sig-1',
      ...body,
    });

    const result = await controller.updateSignature(
      org as any,
      body as any,
      'sig-1'
    );

    expect(signatureService.createOrUpdateSignature).toHaveBeenCalledWith(
      org.id,
      body,
      'sig-1'
    );
    expect(result).toEqual({ id: 'sig-1', ...body });
  });

  it('deleteSignature delegates to SignatureService.deleteSignature', async () => {
    const { controller, signatureService } = makeController();
    signatureService.deleteSignature.mockResolvedValue({ id: 'sig-1' });

    const result = await controller.deleteSignature(org as any, 'sig-1');

    expect(signatureService.deleteSignature).toHaveBeenCalledWith(
      org.id,
      'sig-1'
    );
    expect(result).toEqual({ id: 'sig-1' });
  });

  it('MobileModule.prototype.configure exists', () => {
    expect(typeof MobileModule.prototype.configure).toBe('function');
  });
});
