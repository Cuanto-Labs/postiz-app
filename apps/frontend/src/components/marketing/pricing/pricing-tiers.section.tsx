import Link from 'next/link';
import clsx from 'clsx';
import { capitalize } from 'lodash';
import { pricing } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/pricing';

// Counts at/above this are surfaced as "Unlimited" rather than the raw
// number (mirrors the >10000 heuristic already used for posts_per_month in
// billing/first.billing.component.tsx).
const UNLIMITED_THRESHOLD = 1000;

const RECOMMENDED_TIER = 'TEAM';

// FREE is intentionally skipped — it's not a sellable plan (all limits are
// zero); new signups instead get a timed Standard trial, called out above
// the grid in pricing-page.tsx.
const TIER_ORDER = Object.keys(pricing).filter((key) => key !== 'FREE');

const formatCount = (value: number, unit: string) =>
  value >= UNLIMITED_THRESHOLD
    ? `Unlimited ${unit}`
    : `${value.toLocaleString()} ${unit}`;

const CheckMark = ({ accent }: { accent: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="16"
    height="16"
    viewBox="0 0 16 16"
    fill="none"
    className="shrink-0 mt-[2px]"
  >
    <path
      d="M13.5 4L6 11.5L2.5 8"
      stroke={accent}
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

const buildFeatureRows = (key: string) => {
  const tier = pricing[key];
  return [
    {
      key: 'channels',
      label: `${tier.channel} connected channel${tier.channel === 1 ? '' : 's'}`,
    },
    {
      key: 'posts',
      label: formatCount(tier.posts_per_month, 'posts / month'),
    },
    {
      key: 'image-gen',
      label: tier.image_generator
        ? `${tier.image_generation_count} AI image credits / month`
        : 'AI image generation not included',
    },
    {
      key: 'video-gen',
      label: tier.generate_videos
        ? `${tier.generate_videos} AI video generations / month`
        : 'AI video generation not included',
    },
    {
      key: 'team',
      label: tier.team_members ? 'Unlimited team members' : 'Single user',
    },
    {
      key: 'api',
      label: tier.public_api ? 'Public API access' : 'No public API access',
    },
    {
      key: 'webhooks',
      label: tier.webhooks
        ? formatCount(tier.webhooks, 'webhooks')
        : 'No webhooks',
    },
    {
      key: 'autopost',
      label: tier.autoPost ? 'Auto-post enabled' : 'Manual approval only',
    },
  ];
};

/**
 * Tier cards — every price and limit rendered here comes straight from the
 * `pricing` source of truth. No dollar amounts are hardcoded in this file.
 */
export const PricingTiersSection = () => {
  return (
    <section
      id="plans"
      className="max-w-[1200px] w-full mx-auto px-[24px] pb-[80px]"
    >
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-[20px]">
        {TIER_ORDER.map((key) => {
          const tier = pricing[key];
          const isRecommended = key === RECOMMENDED_TIER;
          const accent = isRecommended ? '#10b981' : '#6366f1';
          const yearlyMonthlyEquivalent = tier.year_price / 12;
          const savingsPercent = Math.round(
            (1 - tier.year_price / (tier.month_price * 12)) * 100
          );

          return (
            <div
              key={key}
              className={clsx(
                'relative flex flex-col rounded-[20px] p-[28px] border bg-white/[0.02]',
                isRecommended ? 'border-[#10b981]' : 'border-white/10'
              )}
            >
              {isRecommended && (
                <div className="absolute -top-[12px] left-1/2 -translate-x-1/2 text-[12px] font-[600] rounded-full px-[12px] py-[4px] bg-[#10b981] text-black">
                  Most popular
                </div>
              )}

              <div className="text-[18px] font-[600] text-white/80">
                {capitalize(key)}
              </div>

              <div className="mt-[16px] flex items-baseline gap-[6px]">
                <span className="text-[40px] font-[700]">
                  ${tier.month_price}
                </span>
                <span className="text-[14px] text-white/50">/ month</span>
              </div>

              <div className="mt-[4px] text-[13px] text-white/50">
                or ${tier.year_price} / year (${yearlyMonthlyEquivalent.toFixed(2)}
                /mo){' '}
                {savingsPercent > 0 && (
                  <span className="text-[#10b981]">
                    — save {savingsPercent}%
                  </span>
                )}
              </div>

              <Link
                href="/auth"
                className="mt-[24px] inline-flex items-center justify-center h-[44px] rounded-[10px] font-[600] text-[14px] transition-colors"
                style={
                  isRecommended
                    ? { backgroundColor: '#10b981', color: '#000' }
                    : { backgroundColor: 'rgba(255,255,255,0.08)', color: '#fff' }
                }
              >
                Start free trial
              </Link>

              <div className="mt-[28px] flex flex-col gap-[12px] text-[14px] text-white/70">
                {buildFeatureRows(key).map((row) => (
                  <div key={row.key} className="flex items-start gap-[8px]">
                    <CheckMark accent={accent} />
                    <span>{row.label}</span>
                  </div>
                ))}
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
};
