import {
  ForbiddenException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { MobileAuthService } from './mobile-auth.service';
import { MobileTokenService } from './mobile-token.service';

function makeDeps() {
  const mobileSessionRepository = {
    create: jest.fn(),
    findByRefreshHash: jest.fn(),
    findByPreviousHash: jest.fn(),
    findById: jest.fn(),
    rotate: jest.fn(),
    touch: jest.fn(),
    revoke: jest.fn(),
    revokeFamily: jest.fn(),
    revokeAllForUser: jest.fn(),
    listActiveForUser: jest.fn(),
  };
  const mobileTokenService = new MobileTokenService();
  const usersService = {
    getUserByEmail: jest.fn(),
    getUserById: jest.fn(),
  };
  const organizationService = {
    getOrgsByUserId: jest.fn().mockResolvedValue([]),
  };

  const service = new MobileAuthService(
    mobileSessionRepository as any,
    mobileTokenService as any,
    usersService as any,
    organizationService as any
  );

  return {
    service,
    mobileSessionRepository,
    mobileTokenService,
    usersService,
    organizationService,
  };
}

const device = { deviceId: 'd1', deviceName: 'iPhone', platform: 'ios' };

describe('MobileAuthService', () => {
  beforeAll(() => {
    process.env.JWT_SECRET = 'test-secret';
  });

  describe('loginEmail', () => {
    it('throws 401 on wrong password', async () => {
      const { service, usersService } = makeDeps();
      usersService.getUserByEmail.mockResolvedValue({
        id: 'u1',
        email: 'a@b.com',
        password: 'hashed',
        activated: true,
      });

      await expect(
        service.loginEmail('a@b.com', 'wrong', device)
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('throws 403 when user is not activated', async () => {
      const { service, usersService } = makeDeps();
      const AuthChecker =
        require('@gitroom/helpers/auth/auth.service').AuthService;
      jest.spyOn(AuthChecker, 'comparePassword').mockReturnValue(true);
      usersService.getUserByEmail.mockResolvedValue({
        id: 'u1',
        email: 'a@b.com',
        password: 'hashed',
        activated: false,
      });

      await expect(
        service.loginEmail('a@b.com', 'correct', device)
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('succeeds and returns a decodable accessToken', async () => {
      const { service, usersService, mobileSessionRepository, mobileTokenService } =
        makeDeps();
      const AuthChecker =
        require('@gitroom/helpers/auth/auth.service').AuthService;
      jest.spyOn(AuthChecker, 'comparePassword').mockReturnValue(true);
      usersService.getUserByEmail.mockResolvedValue({
        id: 'u1',
        email: 'a@b.com',
        password: 'hashed',
        activated: true,
        name: 'Foo',
      });
      mobileSessionRepository.create.mockResolvedValue({ id: 'sess1' });

      const result = await service.loginEmail('a@b.com', 'correct', device);

      expect(result.sessionId).toBe('sess1');
      const decoded = mobileTokenService.verifyAccessToken(
        result.accessToken
      );
      expect(decoded.userId).toBe('u1');
      expect(decoded.sessionId).toBe('sess1');
      expect((result.user as any).password).toBeUndefined();
    });
  });

  describe('refresh', () => {
    it('rotates on happy path', async () => {
      const { service, mobileSessionRepository } = makeDeps();
      mobileSessionRepository.findByRefreshHash.mockResolvedValue({
        id: 'sess1',
        userId: 'u1',
        familyId: 'fam1',
        revokedAt: null,
        expiresAt: new Date(Date.now() + 100000),
      });

      const result = await service.refresh('old-token', device);

      expect(mobileSessionRepository.rotate).toHaveBeenCalled();
      const [rotatedId, oldHashArg, newHashArg] =
        mobileSessionRepository.rotate.mock.calls[0];
      expect(rotatedId).toBe('sess1');
      expect(newHashArg).not.toBe(oldHashArg);
      expect(result.refreshToken).not.toBe('old-token');
      expect(result.sessionId).toBe('sess1');
    });

    it('revokes the family and throws 401 when token only matches previousTokenHash', async () => {
      const { service, mobileSessionRepository } = makeDeps();
      mobileSessionRepository.findByRefreshHash.mockResolvedValue(null);
      mobileSessionRepository.findByPreviousHash.mockResolvedValue({
        id: 'sess1',
        familyId: 'fam1',
      });

      await expect(
        service.refresh('reused-token', device)
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect(mobileSessionRepository.revokeFamily).toHaveBeenCalledWith(
        'fam1'
      );
    });

    it('revokes and throws 401 on expired session', async () => {
      const { service, mobileSessionRepository } = makeDeps();
      mobileSessionRepository.findByRefreshHash.mockResolvedValue({
        id: 'sess1',
        userId: 'u1',
        familyId: 'fam1',
        revokedAt: null,
        expiresAt: new Date(Date.now() - 100000),
      });

      await expect(
        service.refresh('expired-token', device)
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect(mobileSessionRepository.revoke).toHaveBeenCalledWith('sess1');
    });
  });

  describe('revokeDevice', () => {
    it('throws NotFoundException when the session belongs to another user', async () => {
      const { service, mobileSessionRepository } = makeDeps();
      mobileSessionRepository.findById.mockResolvedValue({
        id: 'sess1',
        userId: 'other-user',
      });

      await expect(
        service.revokeDevice('u1', 'sess1')
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(mobileSessionRepository.revoke).not.toHaveBeenCalled();
    });
  });
});
