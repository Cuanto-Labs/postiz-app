import 'reflect-metadata';

// autopost.service.ts is in the tsc baseline; the controller only needs the
// class reference for Nest's design:paramtypes metadata, and every method
// is mocked below, so a lightweight stand-in avoids pulling in its real
// dependency chain (same pattern as mobile-config.controller.spec.ts).
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/autopost/autopost.service',
  () => ({ AutopostService: class AutopostService {} })
);

import { MobileAutopostController } from '@gitroom/backend/api/routes/mobile/mobile-autopost.controller';
import { CHECK_POLICIES_KEY } from '@gitroom/backend/services/auth/permissions/permissions.ability';
import { AuthorizationActions, Sections } from '@gitroom/backend/services/auth/permissions/permission.exception.class';

describe('MobileAutopostController', () => {
  const org = { id: 'org-1' };

  const makeController = () => {
    const autopostsService = {
      getAutoposts: jest.fn(),
      createAutopost: jest.fn(),
      deleteAutopost: jest.fn(),
      changeActive: jest.fn(),
    };

    const controller = new MobileAutopostController(autopostsService as any);

    return { controller, autopostsService };
  };

  it('exposes the /mobile/v1/autopost path', () => {
    expect(Reflect.getMetadata('path', MobileAutopostController)).toBe(
      '/mobile/v1/autopost'
    );
  });

  it('list delegates to AutopostService.getAutoposts(org.id)', async () => {
    const { controller, autopostsService } = makeController();
    autopostsService.getAutoposts.mockResolvedValue([{ id: 'auto-1' }]);

    const result = await controller.list(org as any);

    expect(autopostsService.getAutoposts).toHaveBeenCalledWith('org-1');
    expect(result).toEqual([{ id: 'auto-1' }]);
  });

  it('create delegates to AutopostService.createAutopost(org.id, body)', async () => {
    const { controller, autopostsService } = makeController();
    const body = { title: 'my autopost' };
    autopostsService.createAutopost.mockResolvedValue({ id: 'auto-1' });

    const result = await controller.create(org as any, body as any);

    expect(autopostsService.createAutopost).toHaveBeenCalledWith(
      'org-1',
      body
    );
    expect(result).toEqual({ id: 'auto-1' });
  });

  it('create carries the Create/WEBHOOKS policy metadata', () => {
    const { controller } = makeController();

    expect(
      Reflect.getMetadata(CHECK_POLICIES_KEY, controller.create)
    ).toEqual([[AuthorizationActions.Create, Sections.WEBHOOKS]]);
  });

  it('update delegates to AutopostService.createAutopost(org.id, body, id)', async () => {
    const { controller, autopostsService } = makeController();
    const body = { title: 'my autopost' };
    autopostsService.createAutopost.mockResolvedValue({ id: 'auto-1' });

    const result = await controller.update(org as any, body as any, 'auto-1');

    expect(autopostsService.createAutopost).toHaveBeenCalledWith(
      'org-1',
      body,
      'auto-1'
    );
    expect(result).toEqual({ id: 'auto-1' });
  });

  it('delete delegates to AutopostService.deleteAutopost(org.id, id)', async () => {
    const { controller, autopostsService } = makeController();
    autopostsService.deleteAutopost.mockResolvedValue({ id: 'auto-1' });

    const result = await controller.delete(org as any, 'auto-1');

    expect(autopostsService.deleteAutopost).toHaveBeenCalledWith(
      'org-1',
      'auto-1'
    );
    expect(result).toEqual({ id: 'auto-1' });
  });

  it('changeActive delegates to AutopostService.changeActive(org.id, id, active)', async () => {
    const { controller, autopostsService } = makeController();
    autopostsService.changeActive.mockResolvedValue({ id: 'auto-1' });

    const result = await controller.changeActive(
      org as any,
      'auto-1',
      { active: true } as any
    );

    expect(autopostsService.changeActive).toHaveBeenCalledWith(
      'org-1',
      'auto-1',
      true
    );
    expect(result).toEqual({ id: 'auto-1' });
  });
});
