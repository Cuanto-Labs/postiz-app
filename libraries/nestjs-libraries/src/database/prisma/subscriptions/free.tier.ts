import { SubscriptionTier } from '@prisma/client';

/**
 * Every organization starts one tier above free, at no cost, for a fixed
 * window. FREE is not a member of SubscriptionTier — it is the *absence* of a
 * Subscription row — so the grant has to be a real row carrying an expiry
 * rather than a flag on the organization.
 */
export const FREE_GRANT_TIER: SubscriptionTier = 'STANDARD';
export const FREE_GRANT_MONTHS = 3;

/**
 * `cancelAt` is written by the Stripe webhook path but, before this, nothing
 * ever read it — the tier was taken straight off `subscriptionTier`. A grant
 * with an expiry would therefore have run forever. Resolve entitlements
 * through the helpers below rather than reading `subscriptionTier` directly.
 *
 * The semantics match Stripe's: `cancelAt` is the moment access ends, so the
 * subscription counts as active right up until then, and `null` means no end.
 */
export const isSubscriptionActive = (
  subscription?: { cancelAt?: Date | null } | null
) =>
  !!subscription &&
  (!subscription.cancelAt || subscription.cancelAt > new Date());

/**
 * The organization's tier, or undefined once a grant has lapsed — at which
 * point callers fall back to their own free-tier default.
 *
 * The index signature is load-bearing: `subscription` is a Prisma relation, so
 * it is absent from the generated `Organization` type and only present when the
 * query included it. Without it TypeScript rejects every real caller as having
 * no overlap — which is why these call sites used to carry `@ts-ignore`.
 */
type MaybeSubscribed = {
  subscription?: {
    subscriptionTier: SubscriptionTier;
    cancelAt?: Date | null;
  } | null;
  [key: string]: unknown;
};

export const activeSubscriptionTier = (
  organization?: MaybeSubscribed | null
): SubscriptionTier | undefined =>
  isSubscriptionActive(organization?.subscription)
    ? organization!.subscription!.subscriptionTier
    : undefined;

/** When a grant issued now should lapse. */
export const freeGrantExpiry = (from = new Date()) => {
  const expiry = new Date(from);
  expiry.setMonth(expiry.getMonth() + FREE_GRANT_MONTHS);
  return expiry;
};
