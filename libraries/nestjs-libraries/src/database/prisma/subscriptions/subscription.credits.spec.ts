import dayjs from 'dayjs';

// The real IntegrationService pulls in every social provider (nostr-tools is
// ESM-only); checkCredits never touches it.
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/integrations/integration.service',
  () => ({ IntegrationService: class {} })
);

import { SubscriptionService } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/subscription.service';
import { pricing } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/pricing';

describe('SubscriptionService.checkCredits', () => {
  const getCreditsFrom = jest.fn();
  const service = new SubscriptionService(
    { getCreditsFrom } as any,
    {} as any,
    {} as any,
    {} as any
  );

  beforeEach(() => getCreditsFrom.mockReset());

  it('gives the image quotas per tier: FREE 10, STANDARD 50', () => {
    expect(pricing.FREE.image_generation_count).toBe(10);
    expect(pricing.FREE.image_generator).toBe(true);
    expect(pricing.STANDARD.image_generation_count).toBe(50);
    expect(pricing.STANDARD.image_generator).toBe(true);
  });

  it('counts a FREE org from the 1st of the calendar month', async () => {
    getCreditsFrom.mockResolvedValue(3);

    const res = await service.checkCredits({ id: 'org1' } as any);

    expect(res).toEqual({ credits: 7 });
    const [orgId, from, type] = getCreditsFrom.mock.calls[0];
    expect(orgId).toBe('org1');
    expect(type).toBe('ai_images');
    expect(from.isSame(dayjs().startOf('month'))).toBe(true);
  });

  it('runs a FREE org out at 10 images', async () => {
    getCreditsFrom.mockResolvedValue(10);
    expect(await service.checkCredits({ id: 'org1' } as any)).toEqual({
      credits: 0,
    });
  });

  it('treats a lapsed grant as FREE', async () => {
    getCreditsFrom.mockResolvedValue(0);
    const res = await service.checkCredits({
      id: 'org1',
      subscription: {
        subscriptionTier: 'PRO',
        cancelAt: dayjs().subtract(1, 'day').toDate(),
        createdAt: dayjs().subtract(40, 'day').toDate(),
      },
    } as any);
    expect(res).toEqual({ credits: 10 });
  });

  it('counts a paid org from its billing anniversary', async () => {
    getCreditsFrom.mockResolvedValue(5);
    const createdAt = dayjs().subtract(45, 'day');

    const res = await service.checkCredits({
      id: 'org1',
      subscription: {
        subscriptionTier: 'STANDARD',
        cancelAt: null,
        createdAt: createdAt.toDate(),
      },
    } as any);

    expect(res).toEqual({ credits: 45 });
    expect(getCreditsFrom.mock.calls[0][1].isSame(createdAt.add(1, 'month'))).toBe(
      true
    );
  });

  it('gives FREE no video credits and skips the lookup', async () => {
    expect(
      await service.checkCredits({ id: 'org1' } as any, 'ai_videos')
    ).toEqual({ credits: 0 });
    expect(getCreditsFrom).not.toHaveBeenCalled();
  });
});

describe('premium images', () => {
  const useCredit = jest.fn();
  const service = new SubscriptionService(
    { useCredit } as any,
    {} as any,
    {} as any,
    {} as any
  );
  const realStripe = process.env.STRIPE_PUBLISHABLE_KEY;
  const org = (tier: string) =>
    ({
      id: 'org1',
      subscription: {
        subscriptionTier: tier,
        cancelAt: null,
        createdAt: dayjs().subtract(3, 'day').toDate(),
      },
    } as any);

  beforeEach(() => {
    process.env.STRIPE_PUBLISHABLE_KEY = 'pk_test';
  });
  afterAll(() => {
    process.env.STRIPE_PUBLISHABLE_KEY = realStripe;
  });

  it('opens premium images to PRO and ULTIMATE only', () => {
    expect(service.canUsePremiumImages({ id: 'org1' } as any)).toBe(false);
    expect(service.canUsePremiumImages(org('STANDARD'))).toBe(false);
    expect(service.canUsePremiumImages(org('TEAM'))).toBe(false);
    expect(service.canUsePremiumImages(org('PRO'))).toBe(true);
    expect(service.canUsePremiumImages(org('ULTIMATE'))).toBe(true);
  });

  it('passes the credit amount down to the repository', async () => {
    const func = jest.fn();
    await service.useCredit(org('PRO'), 'ai_images', func, 5);
    expect(useCredit).toHaveBeenCalledWith(org('PRO'), 'ai_images', func, 5);
  });
});
