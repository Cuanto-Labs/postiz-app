import { pricing } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/pricing';

/**
 * Carries a plan choice from the public /pricing page through signup and into
 * the billing page. The public tier cards link to /auth?plan=TEAM&period=month;
 * the auth screens persist that intent here (localStorage survives the email
 * activation detour), and the billing page consumes it once to preselect the
 * tier and open Stripe checkout.
 */
const KEY = 'cs-pending-plan';
const TTL_MS = 7 * 24 * 60 * 60 * 1000; // stale intent after a week

export interface PendingPlan {
  plan: string;
  period: 'month' | 'year';
  ts: number;
}

const isSellablePlan = (plan: string) =>
  plan !== 'FREE' && Object.keys(pricing).includes(plan);

export const storePendingPlan = (
  plan: string | null,
  period: string | null
) => {
  if (typeof window === 'undefined' || !plan || !isSellablePlan(plan)) {
    return;
  }
  const value: PendingPlan = {
    plan,
    period: period === 'year' ? 'year' : 'month',
    ts: Date.now(),
  };
  try {
    window.localStorage.setItem(KEY, JSON.stringify(value));
  } catch {
    // storage unavailable (private mode) — funnel degrades gracefully
  }
};

export const readPendingPlan = (): PendingPlan | null => {
  if (typeof window === 'undefined') {
    return null;
  }
  try {
    const raw = window.localStorage.getItem(KEY);
    if (!raw) {
      return null;
    }
    const value = JSON.parse(raw) as PendingPlan;
    if (
      !isSellablePlan(value?.plan) ||
      Date.now() - (value?.ts || 0) > TTL_MS
    ) {
      window.localStorage.removeItem(KEY);
      return null;
    }
    return value;
  } catch {
    return null;
  }
};

export const clearPendingPlan = () => {
  if (typeof window === 'undefined') {
    return;
  }
  try {
    window.localStorage.removeItem(KEY);
  } catch {
    // ignore
  }
};
