import {
  pricing,
  PricingInnerInterface,
} from '@gitroom/nestjs-libraries/database/prisma/subscriptions/pricing';

/**
 * What a plan actually gives you, in the words a customer would use.
 *
 * The diff is computed from `pricing` rather than written per tier-pair: there
 * are five tiers, so a hand-written matrix would be twenty descriptions that
 * silently rot the next time a number in pricing.ts changes.
 */
type FeatureKind = 'limit' | 'capability';

interface FeatureSpec {
  key: keyof PricingInnerInterface;
  label: string;
  kind: FeatureKind;
  /** Renders a limit value. Unlimited-ish numbers read badly as "1000000". */
  format?: (value: number) => string;
}

const asCount = (unit: string, plural = `${unit}s`) => (value: number) =>
  `${value} ${value === 1 ? unit : plural}`;

export const FEATURES: FeatureSpec[] = [
  {
    key: 'channel',
    label: 'Connected channels',
    kind: 'limit',
    format: asCount('channel'),
  },
  {
    key: 'posts_per_month',
    label: 'Posts per month',
    kind: 'limit',
    format: (v) => (v > 10000 ? 'Unlimited' : `${v}`),
  },
  {
    key: 'image_generation_count',
    label: 'AI images per month',
    kind: 'limit',
    format: asCount('image'),
  },
  {
    key: 'generate_videos',
    label: 'AI videos per month',
    kind: 'limit',
    format: asCount('video'),
  },
  { key: 'webhooks', label: 'Webhooks', kind: 'limit', format: asCount('webhook') },
  { key: 'team_members', label: 'Team members', kind: 'capability' },
  { key: 'ai', label: 'AI auto-complete', kind: 'capability' },
  { key: 'image_generator', label: 'AI image generator', kind: 'capability' },
  { key: 'autoPost', label: 'Auto-posting', kind: 'capability' },
  { key: 'public_api', label: 'Public API', kind: 'capability' },
  {
    key: 'import_from_channels',
    label: 'Import from channels',
    kind: 'capability',
  },
  { key: 'community_features', label: 'Community features', kind: 'capability' },
];

export interface TierChange {
  /** Capabilities switched on, and limits that went up. */
  added: string[];
  /** Capabilities switched off, and limits that came down. */
  removed: string[];
  /** True when the new plan is strictly better on every dimension we track. */
  isUpgrade: boolean;
}

const value = (tier: string, key: keyof PricingInnerInterface) => {
  const plan = pricing[tier];
  return plan ? plan[key] : undefined;
};

/**
 * Describe the move from one tier to another. `from` may be null — that is a
 * brand-new grant, where everything the plan includes counts as added.
 */
export const describeTierChange = (
  from: string | null,
  to: string
): TierChange => {
  const added: string[] = [];
  const removed: string[] = [];

  for (const feature of FEATURES) {
    const before = from ? value(from, feature.key) : undefined;
    const after = value(to, feature.key);

    if (feature.kind === 'capability') {
      if (after === true && before !== true) {
        added.push(feature.label);
      }
      if (after !== true && before === true) {
        removed.push(feature.label);
      }
      continue;
    }

    const beforeNum = typeof before === 'number' ? before : 0;
    const afterNum = typeof after === 'number' ? after : 0;
    if (afterNum === beforeNum) {
      continue;
    }

    const render = feature.format || ((v: number) => `${v}`);
    // On a transition only the destination carries the unit — "5 → 30 channels"
    // rather than "5 channels → 30 channels".
    const line =
      from && beforeNum
        ? `${feature.label}: ${beforeNum} → ${render(afterNum)}`
        : `${feature.label}: ${render(afterNum)}`;

    (afterNum > beforeNum ? added : removed).push(line);
  }

  return { added, removed, isUpgrade: removed.length === 0 && added.length > 0 };
};
