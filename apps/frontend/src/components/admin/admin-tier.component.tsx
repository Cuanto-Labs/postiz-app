'use client';

import React, { useCallback, useMemo, useState } from 'react';
import useSWR from 'swr';
import dayjs from 'dayjs';
import { useFetch } from '@gitroom/helpers/utils/custom.fetch';
import { Button } from '@gitroom/react/form/button';
import { LoadingComponent } from '@gitroom/frontend/components/layout/loading';

type Tier = 'STANDARD' | 'TEAM' | 'PRO' | 'ULTIMATE';

// Mirrors the Prisma enum, which has no FREE — free is the absence of a
// subscription, not a tier that can be granted.
const TIERS: Tier[] = ['STANDARD', 'TEAM', 'PRO', 'ULTIMATE'];

interface OrgRow {
  id: string;
  name: string;
  paymentId: string | null;
  isTrailing: boolean;
  createdAt: string;
  subscription: {
    subscriptionTier: Tier;
    totalChannels: number;
    isLifetime: boolean;
    cancelAt: string | null;
  } | null;
  users: { role: string; user: { email: string } }[];
  _count: { Integration: number };
}

interface Preview {
  from: Tier | null;
  to: Tier;
  added: string[];
  removed: string[];
  isUpgrade: boolean;
}

const useOrgSearch = (query: string) => {
  const fetch = useFetch();
  const loader = useCallback(async () => {
    const res = await fetch(`/admin/organizations?email=${encodeURIComponent(query)}`);
    if (!res.ok) {
      return [] as OrgRow[];
    }
    return (await res.json()) as OrgRow[];
  }, [fetch, query]);

  return useSWR(query.length >= 3 ? `admin-orgs-${query}` : null, loader);
};

const currentPlanLabel = (org: OrgRow) => {
  if (!org.subscription) {
    return 'FREE (no subscription)';
  }
  const { subscriptionTier, isLifetime, cancelAt } = org.subscription;
  if (isLifetime) {
    return `${subscriptionTier} · lifetime`;
  }
  if (cancelAt) {
    return `${subscriptionTier} · through ${dayjs(cancelAt).format('MMM D, YYYY')}`;
  }
  return `${subscriptionTier} · no end date`;
};

const ChangePanel = ({ org, onDone }: { org: OrgRow; onDone: () => void }) => {
  const fetch = useFetch();
  const [tier, setTier] = useState<Tier>('PRO');
  const [duration, setDuration] = useState('1');
  const [durationUnit, setDurationUnit] = useState<'months' | 'days'>('months');
  const [isLifetime, setIsLifetime] = useState(false);
  const [notify, setNotify] = useState(true);
  const [reason, setReason] = useState('');
  const [preview, setPreview] = useState<Preview | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState('');

  const loadPreview = useCallback(async () => {
    setError('');
    const res = await fetch(
      `/admin/organizations/${org.id}/tier-preview?tier=${tier}`
    );
    if (!res.ok) {
      setError('Could not build a preview for that tier.');
      return;
    }
    setPreview((await res.json()) as Preview);
  }, [fetch, org.id, tier]);

  const apply = useCallback(async () => {
    setBusy(true);
    setError('');
    const res = await fetch(`/admin/organizations/${org.id}/tier`, {
      method: 'POST',
      body: JSON.stringify({
        tier,
        isLifetime,
        durationDays:
          !isLifetime && durationUnit === 'days' && duration.trim() !== ''
            ? Number(duration)
            : null,
        durationMonths:
          !isLifetime && durationUnit === 'months' && duration.trim() !== ''
            ? Number(duration)
            : null,
        notify,
        reason: reason.trim() || undefined,
      }),
    });
    setBusy(false);

    if (!res.ok) {
      const body = await res.text();
      setError(body || 'Could not apply that plan.');
      return;
    }

    setDone(
      notify
        ? `Applied ${tier}. The customer has been emailed.`
        : `Applied ${tier}. No email was sent.`
    );
    setPreview(null);
    onDone();
  }, [
    fetch,
    org.id,
    tier,
    isLifetime,
    duration,
    durationUnit,
    notify,
    reason,
    onDone,
  ]);

  if (org.paymentId) {
    return (
      <div className="text-[13px] text-orange-400 bg-newColColor p-[12px] rounded-[6px]">
        This organization pays through Stripe (customer {org.paymentId}). Change
        the plan in Stripe — a manual change here would be overwritten by the
        next webhook.
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-[14px] bg-newColColor p-[16px] rounded-[8px]">
      <div className="flex flex-wrap gap-[10px] items-end">
        <label className="flex flex-col gap-[4px]">
          <span className="text-[12px] text-textColor/60">New plan</span>
          <select
            value={tier}
            onChange={(e) => {
              setTier(e.target.value as Tier);
              setPreview(null);
            }}
            className="bg-newBgColorInner rounded-[6px] h-[38px] px-[10px] outline-none"
          >
            {TIERS.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>
        </label>

        <label className="flex flex-col gap-[4px]">
          <span className="text-[12px] text-textColor/60">Lasts</span>
          <div className="flex gap-[6px]">
            <input
              value={duration}
              onChange={(e) => setDuration(e.target.value.replace(/[^0-9]/g, ''))}
              placeholder="forever"
              inputMode="numeric"
              disabled={isLifetime}
              className="bg-newBgColorInner rounded-[6px] h-[38px] px-[10px] outline-none w-[90px] disabled:opacity-40"
            />
            <select
              value={durationUnit}
              onChange={(e) =>
                setDurationUnit(e.target.value as 'months' | 'days')
              }
              disabled={isLifetime}
              className="bg-newBgColorInner rounded-[6px] h-[38px] px-[10px] outline-none disabled:opacity-40"
            >
              <option value="months">months</option>
              <option value="days">days</option>
            </select>
          </div>
        </label>

        <label className="flex gap-[6px] items-center h-[38px] cursor-pointer">
          <input
            type="checkbox"
            checked={isLifetime}
            onChange={(e) => {
              setIsLifetime(e.target.checked);
              if (e.target.checked) {
                setDuration('');
              }
            }}
          />
          <span className="text-[13px] text-textColor/70">Lifetime</span>
        </label>

        <label className="flex gap-[6px] items-center h-[38px] cursor-pointer">
          <input
            type="checkbox"
            checked={notify}
            onChange={(e) => setNotify(e.target.checked)}
          />
          <span className="text-[13px] text-textColor/70">Email the customer</span>
        </label>
      </div>

      <label className="flex flex-col gap-[4px]">
        <span className="text-[12px] text-textColor/60">
          Note for the customer (optional — appears in the email)
        </span>
        <input
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="Applied as agreed on your call with us."
          className="bg-newBgColorInner rounded-[6px] h-[38px] px-[10px] outline-none"
        />
      </label>

      <div className="flex gap-[10px] items-center">
        <Button onClick={loadPreview} disabled={busy}>
          Preview changes
        </Button>
        <Button onClick={apply} disabled={busy || !preview}>
          {busy ? 'Applying…' : 'Apply plan'}
        </Button>
        {!preview && (
          <span className="text-[12px] text-textColor/40">
            Preview first — it is exactly what the customer will be told.
          </span>
        )}
      </div>

      {!!preview && (
        <div className="flex flex-col gap-[10px] text-[13px] border-t border-newTableBorder pt-[12px]">
          <div className="text-textColor/70">
            {preview.from || 'FREE'} → <strong>{preview.to}</strong>
          </div>
          {!!preview.added.length && (
            <div>
              <div className="text-[#10b981] mb-[4px]">Gains</div>
              {preview.added.map((line) => (
                <div key={line} className="text-textColor/80">
                  + {line}
                </div>
              ))}
            </div>
          )}
          {!!preview.removed.length && (
            <div>
              <div className="text-red-400 mb-[4px]">Loses</div>
              {preview.removed.map((line) => (
                <div key={line} className="text-textColor/80">
                  − {line}
                </div>
              ))}
              <div className="text-[12px] text-textColor/40 mt-[6px]">
                Channels over the new limit are disabled, not deleted.
              </div>
            </div>
          )}
          {!preview.added.length && !preview.removed.length && (
            <div className="text-textColor/50">
              No feature differences — same plan.
            </div>
          )}
        </div>
      )}

      {!!error && <div className="text-[13px] text-red-400">{error}</div>}
      {!!done && <div className="text-[13px] text-[#10b981]">{done}</div>}
    </div>
  );
};

export const AdminTierComponent = () => {
  const [input, setInput] = useState('');
  const [query, setQuery] = useState('');
  const [openId, setOpenId] = useState('');
  const { data, isLoading, mutate } = useOrgSearch(query);

  const rows = useMemo(() => data || [], [data]);

  return (
    <div className="flex flex-col gap-[20px]">
      <div className="text-[20px] font-[700]">Plan changes</div>
      <div className="text-[14px] text-textColor/70">
        Apply a plan to a customer by hand. Runs through the same path as a
        redeemed code — the same limits are enforced and the same email is sent.
        Organizations billed through Stripe are read-only here.
      </div>

      <div className="flex gap-[8px] items-end bg-newBgColorInner p-[16px] rounded-[8px]">
        <label className="flex flex-col gap-[4px] flex-1">
          <span className="text-[12px] text-textColor/60">Customer email</span>
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && setQuery(input.trim())}
            placeholder="name@example.com"
            className="bg-newColColor rounded-[6px] h-[38px] px-[10px] outline-none"
          />
        </label>
        <Button onClick={() => setQuery(input.trim())} disabled={input.trim().length < 3}>
          Search
        </Button>
      </div>

      {isLoading && <LoadingComponent />}

      {!isLoading && !!query && !rows.length && (
        <div className="text-[14px] text-textColor/50">
          No organizations found for “{query}”.
        </div>
      )}

      <div className="flex flex-col gap-[12px]">
        {rows.map((org) => (
          <div
            key={org.id}
            className="bg-newBgColorInner rounded-[8px] p-[16px] flex flex-col gap-[12px]"
          >
            <div className="flex justify-between items-start gap-[12px] flex-wrap">
              <div className="flex flex-col gap-[4px]">
                <div className="font-[600]">{org.name}</div>
                <div className="text-[13px] text-textColor/60">
                  {org.users.map((u) => u.user.email).join(', ')}
                </div>
                <div className="text-[13px] text-textColor/60">
                  {currentPlanLabel(org)} · {org._count.Integration} channels
                  connected
                  {org.isTrailing ? ' · on trial' : ''}
                </div>
              </div>
              <button
                className="underline text-[13px]"
                onClick={() => setOpenId(openId === org.id ? '' : org.id)}
              >
                {openId === org.id ? 'Close' : 'Change plan'}
              </button>
            </div>

            {openId === org.id && (
              <ChangePanel org={org} onDone={() => mutate()} />
            )}
          </div>
        ))}
      </div>
    </div>
  );
};
