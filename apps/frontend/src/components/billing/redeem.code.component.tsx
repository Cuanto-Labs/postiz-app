'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSWRConfig } from 'swr';
import confetti from 'canvas-confetti';
import { LazyMotion, domAnimation, m, useAnimate } from 'motion/react';
import dayjs from 'dayjs';
import { useFetch } from '@gitroom/helpers/utils/custom.fetch';
import { useUser } from '@gitroom/frontend/components/layout/user.context';
import { Input } from '@gitroom/react/form/input';
import { Button } from '@gitroom/react/form/button';
import { useFireEvents } from '@gitroom/helpers/utils/use.fire.events';
import { useT } from '@gitroom/react/translation/get.transation.service.client';

type Tier = 'STANDARD' | 'TEAM' | 'PRO' | 'ULTIMATE';

export interface RedeemSuccess {
  success: true;
  from: Tier | null;
  to: Tier;
  isLifetime: boolean;
  totalChannels: number;
  expiresAt: string | null;
}

interface RedeemFailure {
  success: false;
  reason:
    | 'invalid'
    | 'not_upgradeable'
    | 'has_paid_subscription'
    | 'already_on_tier'
    | 'grant_failed';
}

// Copy per failure reason. The old lifetime screen collapsed every outcome into
// "Code already claimed or invalid code", which made a code that was merely
// attribution-only indistinguishable from a typo.
const FAILURES: Record<RedeemFailure['reason'], string> = {
  invalid: 'That code is not valid, has expired, or has already been used.',
  not_upgradeable: 'That code is valid but does not include a plan.',
  has_paid_subscription:
    'You already have a paid subscription — contact support and we will apply this to your account.',
  already_on_tier: 'You are already on this plan.',
  grant_failed:
    'We could not apply that code just now. Nothing was used — please try again.',
};

const ACCENT = '#10b981';
const ACCENT_ALT = '#6366f1';

const reducedMotion = () =>
  typeof window !== 'undefined' &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches;

/**
 * One restrained burst of thin strips from under the card, in brand colours
 * only. Low particle count and a wide spread read as a finishing flourish
 * rather than a party popper.
 */
const fireConfetti = () => {
  if (reducedMotion()) {
    return;
  }
  confetti({
    particleCount: 34,
    spread: 96,
    startVelocity: 34,
    gravity: 0.9,
    decay: 0.92,
    ticks: 110,
    scalar: 0.75,
    shapes: ['square'],
    colors: [ACCENT, ACCENT_ALT, '#d1fae5'],
    origin: { x: 0.5, y: 0.62 },
    disableForReducedMotion: true,
  });
};

/** Counts to `value` on rAF. A spring would overshoot the exact landing number. */
const CountUp = ({
  value,
  duration = 1100,
}: {
  value: number;
  duration?: number;
}) => {
  const [shown, setShown] = useState(0);
  const frame = useRef<number | undefined>(undefined);

  useEffect(() => {
    if (reducedMotion()) {
      setShown(value);
      return;
    }

    const started = performance.now();
    const step = (now: number) => {
      const progress = Math.min((now - started) / duration, 1);
      // easeOutQuint — moves fast, settles slowly, so the number stays readable.
      setShown(Math.round(value * (1 - Math.pow(1 - progress, 5))));
      if (progress < 1) {
        frame.current = requestAnimationFrame(step);
      }
    };
    frame.current = requestAnimationFrame(step);

    return () => {
      if (frame.current) {
        cancelAnimationFrame(frame.current);
      }
    };
  }, [value, duration]);

  return <>{shown}</>;
};

const Meta = ({ label, value }: { label: string; value: string }) => (
  <div className="flex flex-col gap-[6px]">
    <div className="text-[11px] uppercase tracking-[1.4px] text-textColor/35">
      {label}
    </div>
    <div className="text-[15px] text-textColor/90">{value}</div>
  </div>
);

export const RedeemSuccessCard = ({ result }: { result: RedeemSuccess }) => {
  const t = useT();
  const [scope, animate] = useAnimate();

  useEffect(() => {
    // Fire once the tier has actually changed on screen, not on mount — the
    // burst punctuates the reveal rather than preceding it.
    const timer = setTimeout(fireConfetti, 620);
    if (!reducedMotion()) {
      animate(
        scope.current,
        { opacity: [0, 1], y: [10, 0] },
        { duration: 0.4, ease: [0.16, 1, 0.3, 1] }
      );
    }
    return () => clearTimeout(timer);
  }, [animate, scope]);

  const validity = result.isLifetime
    ? 'Lifetime — never expires'
    : result.expiresAt
    ? `Through ${dayjs(result.expiresAt).format('MMM D, YYYY')}`
    : 'No end date';

  return (
    <div
      ref={scope}
      className="relative rounded-[16px] overflow-hidden"
      style={{
        background: `linear-gradient(160deg, ${ACCENT}2b 0%, transparent 44%), #101314`,
        border: '1px solid rgba(255,255,255,0.07)',
      }}
    >
      {/* A single sheen pass across the card — the premium cue, used once. */}
      <m.div
        aria-hidden
        initial={{ x: '-130%', opacity: 0 }}
        // Fades out as it leaves. Without the opacity keyframe the strip parks
        // at its end position and reads as a permanent seam down the card.
        animate={{ x: '130%', opacity: [0, 1, 0] }}
        transition={{ duration: 1.3, delay: 0.35, ease: 'easeInOut' }}
        className="absolute inset-y-0 w-1/3 pointer-events-none"
        style={{
          background:
            'linear-gradient(100deg, transparent, rgba(255,255,255,0.06), transparent)',
        }}
      />

      <div className="relative p-[36px] flex flex-col gap-[30px]">
        <div className="flex flex-col gap-[10px]">
          <div className="text-[11px] uppercase tracking-[2px] text-[#10b981]">
            {t('redeem_applied', 'Code applied')}
          </div>
          <div className="text-[15px] text-textColor/55 leading-[1.5]">
            {t(
              'redeem_success_sub',
              'Your workspace has been upgraded. Everything below is active immediately.'
            )}
          </div>
        </div>

        <div className="flex items-baseline gap-[16px] flex-wrap">
          {!!result.from && (
            <m.span
              initial={{ opacity: 1 }}
              animate={{ opacity: 0.3 }}
              transition={{ delay: 0.45, duration: 0.4 }}
              className="text-[22px] text-textColor/40 line-through"
            >
              {result.from}
            </m.span>
          )}
          <m.span
            initial={{ opacity: 0, y: 14, filter: 'blur(6px)' }}
            animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
            transition={{ delay: 0.5, duration: 0.55, ease: [0.16, 1, 0.3, 1] }}
            className="text-[52px] leading-[1] font-[700] tracking-[-1px]"
            style={{
              backgroundImage: `linear-gradient(92deg, #ffffff, ${ACCENT})`,
              WebkitBackgroundClip: 'text',
              backgroundClip: 'text',
              color: 'transparent',
            }}
          >
            {result.to}
          </m.span>
        </div>

        <div className="h-[1px] w-full bg-white/[0.06]" />

        <div className="grid grid-cols-2 gap-[28px]">
          <div className="flex flex-col gap-[6px]">
            <div className="text-[11px] uppercase tracking-[1.4px] text-textColor/35">
              {t('redeem_channels', 'Channels')}
            </div>
            <div className="text-[28px] font-[600] text-textColor tracking-[-0.5px] leading-[1]">
              <CountUp value={result.totalChannels} />
            </div>
          </div>
          <Meta label={t('redeem_validity', 'Validity')} value={validity} />
        </div>

        <a
          href="/launches"
          className="h-[46px] px-[22px] self-start flex items-center rounded-[10px] text-[14px] font-[600] text-[#0B0F10] transition-opacity hover:opacity-90"
          style={{ background: ACCENT }}
        >
          {t('redeem_success_cta', 'Go to your calendar')}
        </a>
      </div>
    </div>
  );
};

export const RedeemCode = () => {
  const t = useT();
  const fetch = useFetch();
  const user = useUser();
  const { mutate } = useSWRConfig();
  const fireEvents = useFireEvents();

  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState<RedeemSuccess | null>(null);

  const redeem = useCallback(async () => {
    setBusy(true);
    setError('');

    try {
      const response = await fetch('/billing/redeem', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code: code.trim().toUpperCase() }),
      });

      const data = (await response.json()) as RedeemSuccess | RedeemFailure;

      if (!data?.success) {
        setError(FAILURES[(data as RedeemFailure)?.reason] || FAILURES.invalid);
        return;
      }

      setResult(data);
      setCode('');
      fireEvents('code_redeemed');
      // Refresh the session so the header, channel limit, and trial banner all
      // reflect the new tier without a reload.
      mutate('/user/self');
    } catch (err) {
      setError('Something went wrong redeeming that code. Please try again.');
    } finally {
      setBusy(false);
    }
  }, [code, fetch, mutate, fireEvents]);

  const currentPlan = useMemo(
    () => user?.tier?.current || 'FREE',
    [user?.tier?.current]
  );

  if (!user) {
    return null;
  }

  return (
    <LazyMotion features={domAnimation} strict>
      <div className="max-w-[540px] mx-auto w-full">
        {result ? (
          <RedeemSuccessCard result={result} />
        ) : (
          <div
            className="rounded-[16px] p-[36px] flex flex-col gap-[26px]"
            style={{
              background: '#101314',
              border: '1px solid rgba(255,255,255,0.07)',
            }}
          >
            <div className="flex flex-col gap-[10px]">
              <div className="text-[24px] font-[600] tracking-[-0.4px]">
                {t('redeem_title', 'Redeem a code')}
              </div>
              <div className="text-[15px] text-textColor/55 leading-[1.5]">
                {t(
                  'redeem_subtitle',
                  'Enter the code you were given to apply it to this workspace.'
                )}
              </div>
            </div>

            <div className="flex items-end gap-[12px]">
              <div className="flex-1">
                <Input
                  label="Code"
                  translationKey="label_code"
                  placeholder="XXXXXX"
                  disableForm={true}
                  name="code"
                  value={code}
                  onChange={(e) => setCode(e.target.value.toUpperCase())}
                />
              </div>
              <div className="pb-[8px]">
                <Button
                  disabled={busy || code.trim().length < 2}
                  onClick={redeem}
                >
                  {busy ? t('redeeming', 'Applying…') : t('redeem', 'Apply')}
                </Button>
              </div>
            </div>

            {!!error && (
              <m.div
                initial={{ opacity: 0, y: -4 }}
                animate={{ opacity: 1, y: 0 }}
                className="text-[13px] text-[#f87171] leading-[1.5]"
              >
                {error}
              </m.div>
            )}

            <div className="h-[1px] w-full bg-white/[0.06]" />

            <div className="flex items-center justify-between text-[13px]">
              <span className="text-textColor/35 uppercase tracking-[1.4px] text-[11px]">
                {t('redeem_current', 'Current plan')}
              </span>
              <span className="text-textColor/80">
                {currentPlan}
                {user?.isLifetime ? ' · lifetime' : ''}
              </span>
            </div>
          </div>
        )}
      </div>
    </LazyMotion>
  );
};
