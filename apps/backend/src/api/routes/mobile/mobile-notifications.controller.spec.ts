import 'reflect-metadata';

import { MobileNotificationsController } from '@gitroom/backend/api/routes/mobile/mobile-notifications.controller';

describe('MobileNotificationsController', () => {
  const org = { id: 'org-1' };
  const user = { id: 'user-1' };

  const makeController = () => {
    const notificationsService = {
      getMainPageCount: jest.fn(),
      getNotifications: jest.fn(),
    };

    const controller = new MobileNotificationsController(
      notificationsService as any
    );

    return { controller, notificationsService };
  };

  it('exposes the /mobile/v1/notifications path', () => {
    expect(Reflect.getMetadata('path', MobileNotificationsController)).toBe(
      '/mobile/v1/notifications'
    );
  });

  it('mainPageList delegates to getMainPageCount(org.id, user.id)', async () => {
    const { controller, notificationsService } = makeController();
    notificationsService.getMainPageCount.mockResolvedValue({ count: 3 });

    const result = await controller.mainPageList(user as any, org as any);

    expect(notificationsService.getMainPageCount).toHaveBeenCalledWith(
      org.id,
      user.id
    );
    expect(result).toEqual({ count: 3 });
  });

  it('notifications delegates to getNotifications(org.id, user.id)', async () => {
    const { controller, notificationsService } = makeController();
    notificationsService.getNotifications.mockResolvedValue([
      { id: 'n-1' },
    ]);

    const result = await controller.notifications(user as any, org as any);

    expect(notificationsService.getNotifications).toHaveBeenCalledWith(
      org.id,
      user.id
    );
    expect(result).toEqual([{ id: 'n-1' }]);
  });
});
