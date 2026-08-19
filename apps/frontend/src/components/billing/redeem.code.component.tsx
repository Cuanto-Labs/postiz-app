'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { useSWRConfig } from 'swr';
import confetti from 'canvas-confetti';
import { LazyMotion, domAnimation, m, useAnimate } from 'motion/react';
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
}

interface RedeemFailure {
  success: false;
  reason:
    | 'invalid'
    | 'not_upgradeable'
    | 'has_paid_subscription'
    | 'already_on_tier';
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
};

/** Brand accents, matching the rest of the app. */
const ACCENT = '#10b981';
const ACCENT_ALT = '#6366f1';

const fireConfetti = () => {
  // Two opposing cones rather than one burst — reads as a celebration across
  // the whole card instead of a spray from the middle.
  const base = {
    particleCount: 60,
    spread: 70,
    startVelocity: 45,
    ticks: 140,
    colors: [ACCENT, ACCENT_ALT, '#ffffff'],
    disableForReducedMotion: true,
  };
  confetti({ ...base, angle: 60, origin: { x: 0.1, y: 0.75 } });
  confetti({ ...base, angle: 120, origin: { x: 0.9, y: 0.75 } });
};

/**
 * Counts to `value` over `duration`. Deliberately hand-rolled on rAF rather
 * than pulled from an animation lib: it is ten lines, and the alternative
 * (a spring on a number) fights the exact landing value.
 */
const CountUp = ({ value, duration = 900 }: { value: number; duration?: number }) => {
  const [shown, setShown] = useState(0);
  const frame = useRef<number | undefined>(undefined);

  useEffect(() => {
    if (
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches
    ) {
      setShown(value);
      return;
    }

    const started = performance.now();
    const step = (now: number) => {
      const progress = Math.min((now - started) / duration, 1);
      // easeOutCubic — fast then settling, so the final number is readable.
      setShown(Math.round(value * (1 - Math.pow(1 - progress, 3))));
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

const TierBadge = ({ tier, muted }: { tier: string; muted?: boolean }) => (
  <div
    className={`px-[14px] py-[6px] rounded-[8px] text-[16px] font-[700] tracking-[0.5px] ${
      muted
        ? 'bg-newColColor text-textColor/40 line-through'
        : 'text-[#0E0E0E]'
    }`}
    style={muted ? undefined : { background: ACCENT }}
  >
    {tier}
  </div>
);

export const RedeemSuccessCard = ({ result }: { result: RedeemSuccess }) => {
  const t = useT();
  const [scope, animate] = useAnimate();

  useEffect(() => {
    fireConfetti();
    // A second, smaller pop once the badge has settled — the card reads as
    // finished rather than as one instant flash.
    const timer = setTimeout(fireConfetti, 550);
    animate(
      scope.current,
      { scale: [0.94, 1.04, 1] },
      { duration: 0.55, ease: 'easeOut' }
    );
    return () => clearTimeout(timer);
  }, [animate, scope]);

  return (
    <m.div
      ref={scope}
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, ease: 'easeOut' }}
      className="border border-customColor6 bg-sixth p-[32px] rounded-[8px] flex flex-col gap-[24px] items-center text-center"
      style={{ boxShadow: `0 0 0 1px ${ACCENT}22, 0 18px 60px -30px ${ACCENT}` }}
    >
      <div className="text-[28px] font-[700]">
        {t('redeem_success_title', "You're upgraded")}
      </div>

      <div className="flex items-center gap-[14px]">
        {!!result.from && <TierBadge tier={result.from} muted />}
        {!!result.from && <div className="text-textColor/40 text-[20px]">→</div>}
        <m.div
          initial={{ scale: 0.6, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ delay: 0.15, type: 'spring', stiffness: 320, damping: 18 }}
        >
          <TierBadge tier={result.to} />
        </m.div>
      </div>

      <div className="text-[16px] text-customColor18">
        <span className="text-[34px] font-[700] text-textColor">
          <CountUp value={result.totalChannels} />
        </span>{' '}
        {result.totalChannels === 1 ? 'channel' : 'channels'} unlocked
        {result.isLifetime ? ' · lifetime' : ''}
      </div>

      <a
        href="/launches"
        className="px-[20px] h-[44px] flex items-center rounded-[10px] text-[#0E0E0E] font-[600]"
        style={{ background: ACCENT }}
      >
        {t('redeem_success_cta', 'Start posting')}
      </a>
    </m.div>
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

  if (!user) {
    return null;
  }

  return (
    <LazyMotion features={domAnimation} strict>
      <div className="max-w-[560px] mx-auto w-full flex flex-col gap-[20px]">
        {result ? (
          <RedeemSuccessCard result={result} />
        ) : (
          <m.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, ease: 'easeOut' }}
            className="border border-customColor6 bg-sixth p-[24px] rounded-[8px] flex flex-col gap-[16px]"
          >
            <div className="text-[24px] font-[700]">
              {t('redeem_title', 'Redeem a code')}
            </div>
            <div className="text-[14px] text-textColor/70">
              {t(
                'redeem_subtitle',
                'Have a code? Enter it below to upgrade your plan instantly.'
              )}
            </div>

            <div className="flex items-end gap-[10px]">
              <div className="flex-1">
                <Input
                  label="Code"
                  translationKey="label_code"
                  placeholder="YOURCODE"
                  disableForm={true}
                  name="code"
                  value={code}
                  onChange={(e) => setCode(e.target.value.toUpperCase())}
                />
              </div>
              <div className="pb-[8px]">
                <Button disabled={busy || code.trim().length < 2} onClick={redeem}>
                  {busy ? t('redeeming', 'Redeeming…') : t('redeem', 'Redeem')}
                </Button>
              </div>
            </div>

            {!!error && (
              <m.div
                initial={{ opacity: 0, x: -6 }}
                animate={{ opacity: 1, x: 0 }}
                className="text-[13px] text-red-400"
              >
                {error}
              </m.div>
            )}

            <div className="text-[13px] text-textColor/50">
              {t('redeem_current', 'Current plan:')}{' '}
              <span className="text-textColor/80">
                {user?.tier?.current || 'FREE'}
              </span>
              {user?.isLifetime ? ' · lifetime' : ''}
            </div>
          </m.div>
        )}
      </div>
    </LazyMotion>
  );
};
