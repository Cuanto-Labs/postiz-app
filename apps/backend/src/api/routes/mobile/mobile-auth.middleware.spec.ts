import { ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { AuthService as AuthChecker } from '@gitroom/helpers/auth/auth.service';
import { MobileTokenService } from '@gitroom/nestjs-libraries/mobile/mobile-token.service';
import { MobileAuthMiddleware } from './mobile-auth.middleware';

describe('MobileAuthMiddleware', () => {
  let tokenService: MobileTokenService;
  let sessionRepository: {
    findById: jest.Mock;
    touch: jest.Mock;
  };
  let usersService: { getUserById: jest.Mock };
  let organizationService: {
    getOrgsByUserId: jest.Mock;
    updateApiKey: jest.Mock;
  };
  let middleware: MobileAuthMiddleware;
  let next: jest.Mock;

  beforeAll(() => {
    process.env.JWT_SECRET = 'test-secret';
  });

  beforeEach(() => {
    tokenService = new MobileTokenService();
    sessionRepository = {
      findById: jest.fn(),
      touch: jest.fn(),
    };
    usersService = { getUserById: jest.fn() };
    organizationService = {
      getOrgsByUserId: jest.fn(),
      updateApiKey: jest.fn(),
    };
    next = jest.fn();

    middleware = new MobileAuthMiddleware(
      tokenService,
      sessionRepository as any,
      usersService as any,
      organizationService as any
    );
  });

  const buildReq = (authorization?: string, showorg?: string) =>
    ({
      headers: {
        ...(authorization ? { authorization } : {}),
        ...(showorg ? { showorg } : {}),
      },
    } as any);

  it('throws Unauthorized when no bearer token is present', async () => {
    await expect(
      middleware.use(buildReq(), {} as any, next)
    ).rejects.toThrow(UnauthorizedException);
    expect(next).not.toHaveBeenCalled();
  });

  it('throws Unauthorized for a web-issued JWT (no mobile aud)', async () => {
    const webToken = AuthChecker.signJWT({ id: 'u1' });

    await expect(
      middleware.use(buildReq(`Bearer ${webToken}`), {} as any, next)
    ).rejects.toThrow(UnauthorizedException);
    expect(next).not.toHaveBeenCalled();
  });

  it('throws Unauthorized for a revoked session', async () => {
    const token = tokenService.signAccessToken({
      userId: 'u1',
      sessionId: 's1',
    });
    sessionRepository.findById.mockResolvedValue({
      id: 's1',
      userId: 'u1',
      familyId: 'f1',
      revokedAt: new Date(),
    });

    await expect(
      middleware.use(buildReq(`Bearer ${token}`), {} as any, next)
    ).rejects.toThrow(UnauthorizedException);
    expect(next).not.toHaveBeenCalled();
  });

  it('throws Forbidden when showorg does not match any membership', async () => {
    const token = tokenService.signAccessToken({
      userId: 'u1',
      sessionId: 's1',
    });
    sessionRepository.findById.mockResolvedValue({
      id: 's1',
      userId: 'u1',
      familyId: 'f1',
      revokedAt: null,
    });
    usersService.getUserById.mockResolvedValue({
      id: 'u1',
      activated: true,
      password: 'secret',
    });
    organizationService.getOrgsByUserId.mockResolvedValue([
      { id: 'org-a', apiKey: 'k', users: [{ disabled: false }] },
    ]);

    await expect(
      middleware.use(
        buildReq(`Bearer ${token}`, 'org-not-a-member'),
        {} as any,
        next
      )
    ).rejects.toThrow(ForbiddenException);
    expect(next).not.toHaveBeenCalled();
  });

  it('selects the first non-disabled org when showorg is absent', async () => {
    const token = tokenService.signAccessToken({
      userId: 'u1',
      sessionId: 's1',
    });
    sessionRepository.findById.mockResolvedValue({
      id: 's1',
      userId: 'u1',
      familyId: 'f1',
      revokedAt: null,
    });
    usersService.getUserById.mockResolvedValue({
      id: 'u1',
      activated: true,
      password: 'secret',
    });
    organizationService.getOrgsByUserId.mockResolvedValue([
      { id: 'org-disabled', apiKey: 'k', users: [{ disabled: true }] },
      { id: 'org-a', apiKey: 'k', users: [{ disabled: false }] },
      { id: 'org-b', apiKey: 'k', users: [{ disabled: false }] },
    ]);

    const req = buildReq(`Bearer ${token}`);
    await middleware.use(req, {} as any, next);

    expect(req.org.id).toBe('org-a');
    expect(next).toHaveBeenCalled();
  });

  it('sets req.user (without password) and req.org on success', async () => {
    const token = tokenService.signAccessToken({
      userId: 'u1',
      sessionId: 's1',
    });
    sessionRepository.findById.mockResolvedValue({
      id: 's1',
      userId: 'u1',
      familyId: 'f1',
      revokedAt: null,
    });
    usersService.getUserById.mockResolvedValue({
      id: 'u1',
      activated: true,
      password: 'secret',
    });
    organizationService.getOrgsByUserId.mockResolvedValue([
      { id: 'org-a', apiKey: 'k', users: [{ disabled: false }] },
    ]);

    const req = buildReq(`Bearer ${token}`);
    await middleware.use(req, {} as any, next);

    expect(req.user.password).toBeUndefined();
    expect(req.user.id).toBe('u1');
    expect(req.org.id).toBe('org-a');
    expect(req.mobileSession).toEqual({ id: 's1', familyId: 'f1' });
    expect(next).toHaveBeenCalled();
  });
});
