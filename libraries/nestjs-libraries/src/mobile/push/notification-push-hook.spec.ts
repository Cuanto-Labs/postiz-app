import 'reflect-metadata';

jest.mock('nestjs-temporal-core', () => ({
  TemporalService: class TemporalService {},
}));
jest.mock('@temporalio/common', () => ({
  TypedSearchAttributes: class TypedSearchAttributes {},
  SearchAttributeType: { TEXT: 'TEXT' },
  defineSearchAttributeKey: jest.fn(() => ({})),
}));
jest.mock('@gitroom/nestjs-libraries/services/email.service', () => ({
  EmailService: class EmailService {},
}));

import { NotificationService } from '@gitroom/nestjs-libraries/database/prisma/notifications/notification.service';

describe('NotificationService push hook', () => {
  const repoFake = { createNotification: jest.fn() };
  const emailFake = {};
  const orgRepoFake = {};
  const temporalFake = {};
  const pushFake = { notifyFromNotification: jest.fn() };

  const build = () =>
    new NotificationService(
      repoFake as any,
      emailFake as any,
      orgRepoFake as any,
      temporalFake as any,
      pushFake as any
    );

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('calls createNotification then push.notifyFromNotification, no email', async () => {
    const service = build();
    await service.inAppNotification('org', 's', 'm', false, false, 'fail');

    expect(repoFake.createNotification).toHaveBeenCalledWith('org', 'm');
    expect(pushFake.notifyFromNotification).toHaveBeenCalledWith(
      'org',
      's',
      'm',
      'fail'
    );
  });

  it('calls push exactly once when sendEmail=true, digest=false', async () => {
    const service = build();
    // avoid touching real email/temporal path
    (service as any)._emailService = { sendEmail: jest.fn() };
    (service as any)._organizationRepository = {
      getAllUsersOrgs: jest.fn().mockResolvedValue({ users: [] }),
    };

    await service.inAppNotification('org', 's', 'm', true, false, 'success');

    expect(pushFake.notifyFromNotification).toHaveBeenCalledTimes(1);
  });

  it('does not reject when push rejects', async () => {
    pushFake.notifyFromNotification.mockRejectedValueOnce(new Error('boom'));
    const service = build();

    await expect(
      service.inAppNotification('org', 's', 'm', false, false, 'info')
    ).resolves.toBeUndefined();
  });
});
