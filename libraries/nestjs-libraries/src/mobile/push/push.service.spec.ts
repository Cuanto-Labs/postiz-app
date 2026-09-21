import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PushService } from './push.service';

function makeDeps() {
  const pushDeviceRepository = {
    upsertByToken: jest.fn(),
    findByToken: jest.fn(),
    deleteByToken: jest.fn(),
    updatePrefs: jest.fn(),
    disableByToken: jest.fn(),
    listActiveForUsers: jest.fn().mockResolvedValue([]),
    deleteAllForUser: jest.fn(),
  };
  const apnsClient = {
    send: jest.fn(),
  };
  const organizationRepository = {
    getAllUsersOrgs: jest.fn().mockResolvedValue({ users: [] }),
  };

  const service = new PushService(
    pushDeviceRepository as any,
    apnsClient as any,
    organizationRepository as any
  );

  return { service, pushDeviceRepository, apnsClient, organizationRepository };
}

describe('PushService', () => {
  describe('classify', () => {
    it('maps fail type to post.failed', () => {
      const { service } = makeDeps();
      const event = service.classify('Error posting on X', 'details', 'fail');
      expect(event).toEqual({
        kind: 'post.failed',
        title: 'Error posting on X',
        body: 'details',
      });
    });

    it('maps a published success subject to post.published with link', () => {
      const { service } = makeDeps();
      const event = service.classify(
        'Your post has been published on X',
        'Your post has been published on X at https://x.com/status/1',
        'success'
      );
      expect(event?.kind).toBe('post.published');
      expect(event?.link).toBe('https://x.com/status/1');
    });

    it('maps a reconnect info subject/message to channel.reconnect_needed', () => {
      const { service } = makeDeps();
      const event = service.classify(
        "Could not refresh your X channel",
        'Please go back to the system and connect it again',
        'info'
      );
      expect(event?.kind).toBe('channel.reconnect_needed');
    });

    it('returns null for a non-reconnect info notification', () => {
      const { service } = makeDeps();
      const event = service.classify('Some other info', 'nothing relevant', 'info');
      expect(event).toBeNull();
    });

    it('returns null for a success notification that is not a publish message', () => {
      const { service } = makeDeps();
      const event = service.classify('Something else happened', 'body', 'success');
      expect(event).toBeNull();
    });
  });

  describe('notifyOrg', () => {
    it('skips devices whose prefs disable the event kind', async () => {
      const { service, organizationRepository, pushDeviceRepository, apnsClient } =
        makeDeps();
      organizationRepository.getAllUsersOrgs.mockResolvedValue({
        users: [{ user: { id: 'u1' } }],
      });
      pushDeviceRepository.listActiveForUsers.mockResolvedValue([
        {
          apnsToken: 't1',
          environment: 'production',
          bundleId: 'com.cuantolabs.socials',
          prefs: { 'post.published': false },
        },
      ]);

      const result = await service.notifyOrg('org1', {
        kind: 'post.published',
        title: 't',
        body: 'b',
      });

      expect(apnsClient.send).not.toHaveBeenCalled();
      expect(result).toEqual({ sent: 0, failed: 0, disabled: 0 });
    });

    it('disables the device on a 410/unregistered send result', async () => {
      const { service, organizationRepository, pushDeviceRepository, apnsClient } =
        makeDeps();
      organizationRepository.getAllUsersOrgs.mockResolvedValue({
        users: [{ user: { id: 'u1' } }],
      });
      pushDeviceRepository.listActiveForUsers.mockResolvedValue([
        {
          apnsToken: 't1',
          environment: 'production',
          bundleId: 'com.cuantolabs.socials',
          prefs: {},
        },
      ]);
      apnsClient.send.mockResolvedValue({
        ok: false,
        status: 410,
        unregistered: true,
      });

      const result = await service.notifyOrg('org1', {
        kind: 'post.failed',
        title: 't',
        body: 'b',
      });

      expect(pushDeviceRepository.disableByToken).toHaveBeenCalledWith('t1');
      expect(result).toEqual({ sent: 0, failed: 1, disabled: 1 });
    });

    it('sends payload with category and passes device environment through', async () => {
      const { service, organizationRepository, pushDeviceRepository, apnsClient } =
        makeDeps();
      organizationRepository.getAllUsersOrgs.mockResolvedValue({
        users: [{ user: { id: 'u1' } }],
      });
      pushDeviceRepository.listActiveForUsers.mockResolvedValue([
        {
          apnsToken: 't1',
          environment: 'sandbox',
          bundleId: 'com.cuantolabs.socials',
          prefs: {},
        },
      ]);
      apnsClient.send.mockResolvedValue({ ok: true, status: 200, unregistered: false });

      const result = await service.notifyOrg('org1', {
        kind: 'channel.reconnect_needed',
        title: 't',
        body: 'b',
        link: 'https://x.com/1',
      });

      expect(apnsClient.send).toHaveBeenCalledWith(
        expect.objectContaining({
          token: 't1',
          environment: 'sandbox',
          topic: 'com.cuantolabs.socials',
          collapseId: expect.any(String),
          payload: expect.objectContaining({
            aps: expect.objectContaining({
              category: 'CHANNEL_RECONNECT',
              'thread-id': 'channel.reconnect_needed',
            }),
          }),
        })
      );
      const sentCollapseId = apnsClient.send.mock.calls[0][0].collapseId;
      expect(sentCollapseId).not.toBe('https://x.com/1');
      expect(Buffer.byteLength(sentCollapseId, 'utf8')).toBeLessThanOrEqual(64);
      expect(result).toEqual({ sent: 1, failed: 0, disabled: 0 });
    });

    it('derives a collapseId <= 64 bytes from a very long link instead of using the raw URL', async () => {
      const { service, organizationRepository, pushDeviceRepository, apnsClient } =
        makeDeps();
      organizationRepository.getAllUsersOrgs.mockResolvedValue({
        users: [{ user: { id: 'u1' } }],
      });
      pushDeviceRepository.listActiveForUsers.mockResolvedValue([
        {
          apnsToken: 't1',
          environment: 'production',
          bundleId: 'com.cuantolabs.socials',
          prefs: {},
        },
      ]);
      apnsClient.send.mockResolvedValue({ ok: true, status: 200, unregistered: false });

      const longLink = 'https://x.com/status/' + '1'.repeat(500);
      await service.notifyOrg('org1', {
        kind: 'post.published',
        title: 't',
        body: 'b',
        link: longLink,
      });

      const sentCollapseId = apnsClient.send.mock.calls[0][0].collapseId;
      expect(sentCollapseId).not.toBe(longLink);
      expect(Buffer.byteLength(sentCollapseId, 'utf8')).toBeLessThanOrEqual(64);
    });

    it('sends fan-out in parallel and passes orgId to the device lookup', async () => {
      const { service, organizationRepository, pushDeviceRepository, apnsClient } =
        makeDeps();
      organizationRepository.getAllUsersOrgs.mockResolvedValue({
        users: [{ user: { id: 'u1' } }, { user: { id: 'u2' } }],
      });
      pushDeviceRepository.listActiveForUsers.mockResolvedValue([
        {
          apnsToken: 't1',
          environment: 'production',
          bundleId: 'com.cuantolabs.socials',
          prefs: {},
        },
        {
          apnsToken: 't2',
          environment: 'production',
          bundleId: 'com.cuantolabs.socials',
          prefs: {},
        },
      ]);
      apnsClient.send.mockResolvedValue({ ok: true, status: 200, unregistered: false });

      const result = await service.notifyOrg('org1', {
        kind: 'post.published',
        title: 't',
        body: 'b',
      });

      expect(pushDeviceRepository.listActiveForUsers).toHaveBeenCalledWith(
        ['u1', 'u2'],
        'org1'
      );
      expect(apnsClient.send).toHaveBeenCalledTimes(2);
      expect(result).toEqual({ sent: 2, failed: 0, disabled: 0 });
    });
  });

  describe('setPrefs', () => {
    it('rejects an unknown pref key', async () => {
      const { service } = makeDeps();
      await expect(
        service.setPrefs('u1', 't1', { 'not.a.kind': true } as any)
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('throws NotFoundException when no device matched', async () => {
      const { service, pushDeviceRepository } = makeDeps();
      pushDeviceRepository.updatePrefs.mockResolvedValue({ count: 0 });

      await expect(
        service.setPrefs('u1', 't1', { 'post.published': true })
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('rejects a non-boolean (nested) pref value', async () => {
      const { service } = makeDeps();
      await expect(
        service.setPrefs('u1', 't1', {
          'post.published': { nested: true },
        } as any)
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('registerDevice', () => {
    it('rejects an unknown pref key', async () => {
      const { service } = makeDeps();
      await expect(
        service.registerDevice('u1', 'org1', {
          apnsToken: 't1',
          environment: 'production',
          prefs: { 'not.a.kind': true } as any,
        })
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('rejects a non-boolean pref value', async () => {
      const { service } = makeDeps();
      await expect(
        service.registerDevice('u1', 'org1', {
          apnsToken: 't1',
          environment: 'production',
          prefs: { 'post.published': 'yes' } as any,
        })
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('accepts valid boolean prefs', async () => {
      const { service, pushDeviceRepository } = makeDeps();
      await service.registerDevice('u1', 'org1', {
        apnsToken: 't1',
        environment: 'production',
        prefs: { 'post.published': true },
      });
      expect(pushDeviceRepository.upsertByToken).toHaveBeenCalled();
    });
  });

  describe('notifyFromNotification', () => {
    it('returns zeros without notifying when classify yields null', async () => {
      const { service, organizationRepository } = makeDeps();
      const result = await service.notifyFromNotification(
        'org1',
        'irrelevant subject',
        'irrelevant body',
        'info'
      );
      expect(result).toEqual({ sent: 0, failed: 0, disabled: 0 });
      expect(organizationRepository.getAllUsersOrgs).not.toHaveBeenCalled();
    });

    it('swallows a repository throw and returns zeros', async () => {
      const { service, organizationRepository } = makeDeps();
      organizationRepository.getAllUsersOrgs.mockRejectedValue(new Error('db down'));

      const result = await service.notifyFromNotification(
        'org1',
        'Your post has been published on X',
        'Your post has been published on X at https://x.com/1',
        'success'
      );

      expect(result).toEqual({ sent: 0, failed: 0, disabled: 0 });
    });
  });
});
