'use client';

import React, { useCallback, useState } from 'react';
import useSWR from 'swr';
import { useFetch } from '@gitroom/helpers/utils/custom.fetch';
import { Button } from '@gitroom/react/form/button';
import { LoadingComponent } from '@gitroom/frontend/components/layout/loading';

type Tier = 'STANDARD' | 'TEAM' | 'PRO' | 'ULTIMATE';

interface InviteCode {
  id: string;
  code: string;
  label: string | null;
  active: boolean;
  expiresAt: string | null;
  timesUsed: number;
  tier: Tier | null;
  isLifetime: boolean;
  maxUses: number | null;
  createdAt: string;
}

// Mirrors the Prisma SubscriptionTier enum, which deliberately has no FREE —
// free is the absence of a subscription, not a tier a code can grant.
const TIERS: Tier[] = ['STANDARD', 'TEAM', 'PRO', 'ULTIMATE'];

export const AdminCodesComponent = () => {
  const fetch = useFetch();
  const [code, setCode] = useState('');
  const [label, setLabel] = useState('');
  const [tier, setTier] = useState<Tier | ''>('');
  const [isLifetime, setIsLifetime] = useState(false);
  const [maxUses, setMaxUses] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const loader = useCallback(async () => {
    const res = await fetch('/admin/invite-codes');
    return (await res.json()) as InviteCode[];
  }, [fetch]);

  const { data, isLoading, mutate } = useSWR('admin-invite-codes', loader);

  const create = useCallback(async () => {
    if (!code.trim()) {
      return;
    }
    setBusy(true);
    setError('');
    const res = await fetch('/admin/invite-codes', {
      method: 'POST',
      body: JSON.stringify({
        code: code.trim(),
        label: label.trim(),
        tier: tier || null,
        isLifetime,
        maxUses: maxUses.trim() === '' ? null : Number(maxUses),
      }),
    });
    setBusy(false);
    if (!res.ok) {
      setError('Could not save that code — check the tier and max uses.');
      return;
    }
    setCode('');
    setLabel('');
    setTier('');
    setIsLifetime(false);
    setMaxUses('');
    mutate();
  }, [code, label, tier, isLifetime, maxUses, fetch, mutate]);

  const toggle = useCallback(
    async (row: InviteCode) => {
      await fetch(`/admin/invite-codes/${row.id}`, {
        method: 'PUT',
        body: JSON.stringify({ active: !row.active }),
      });
      mutate();
    },
    [fetch, mutate]
  );

  const remove = useCallback(
    async (row: InviteCode) => {
      if (!window.confirm(`Delete code "${row.code}"?`)) {
        return;
      }
      await fetch(`/admin/invite-codes/${row.id}`, { method: 'DELETE' });
      mutate();
    },
    [fetch, mutate]
  );

  if (isLoading) {
    return <LoadingComponent />;
  }

  return (
    <div className="flex flex-col gap-[20px]">
      <div className="text-[20px] font-[700]">Invite codes</div>
      <div className="text-[14px] text-textColor/70">
        Codes carried by landing pages as{' '}
        <code className="bg-newColColor px-[6px] py-[2px] rounded-[4px]">
          /join/&lt;page&gt;
        </code>{' '}
        and forwarded to registration as{' '}
        <code className="bg-newColColor px-[6px] py-[2px] rounded-[4px]">
          ?invite=CODE
        </code>
        . Registration is open without a code. A code with no tier is
        attribution-only; give it a tier and it grants that plan — at signup, or
        redeemed later by an existing user at{' '}
        <code className="bg-newColColor px-[6px] py-[2px] rounded-[4px]">
          /billing/redeem
        </code>
        . An inactive, expired, or fully-used code is rejected.
      </div>

      <div className="flex flex-wrap gap-[8px] items-end bg-newBgColorInner p-[16px] rounded-[8px]">
        <label className="flex flex-col gap-[4px]">
          <span className="text-[12px] text-textColor/60">Code</span>
          <input
            value={code}
            onChange={(e) => setCode(e.target.value.toUpperCase())}
            placeholder="LAUNCH"
            className="bg-newColColor rounded-[6px] h-[38px] px-[10px] outline-none uppercase"
          />
        </label>
        <label className="flex flex-col gap-[4px] flex-1 min-w-[180px]">
          <span className="text-[12px] text-textColor/60">Label (optional)</span>
          <input
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            placeholder="Spring launch campaign"
            className="bg-newColColor rounded-[6px] h-[38px] px-[10px] outline-none"
          />
        </label>
        <label className="flex flex-col gap-[4px]">
          <span className="text-[12px] text-textColor/60">Grants tier</span>
          <select
            value={tier}
            onChange={(e) => setTier(e.target.value as Tier | '')}
            className="bg-newColColor rounded-[6px] h-[38px] px-[10px] outline-none"
          >
            <option value="">None (attribution only)</option>
            {TIERS.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-[4px] w-[110px]">
          <span className="text-[12px] text-textColor/60">Max uses</span>
          <input
            value={maxUses}
            onChange={(e) => setMaxUses(e.target.value.replace(/[^0-9]/g, ''))}
            placeholder="∞"
            inputMode="numeric"
            className="bg-newColColor rounded-[6px] h-[38px] px-[10px] outline-none"
          />
        </label>
        <label className="flex gap-[6px] items-center h-[38px] cursor-pointer">
          <input
            type="checkbox"
            checked={isLifetime}
            disabled={!tier}
            onChange={(e) => setIsLifetime(e.target.checked)}
          />
          <span className="text-[13px] text-textColor/70">Lifetime</span>
        </label>
        <Button onClick={create} disabled={busy || !code.trim()}>
          Add code
        </Button>
      </div>

      {!!error && <div className="text-[13px] text-red-400">{error}</div>}

      <table className="w-full text-[14px]">
        <thead>
          <tr className="text-left text-textColor/60 border-b border-newTableBorder">
            <th className="py-[8px]">Code</th>
            <th className="py-[8px]">Label</th>
            <th className="py-[8px]">Grants</th>
            <th className="py-[8px]">Uses</th>
            <th className="py-[8px]">Status</th>
            <th className="py-[8px]" />
          </tr>
        </thead>
        <tbody>
          {(data || []).map((row) => (
            <tr key={row.id} className="border-b border-newTableBorder">
              <td className="py-[10px] font-[600]">{row.code}</td>
              <td className="py-[10px] text-textColor/70">
                {row.label || '—'}
              </td>
              <td className="py-[10px]">
                {row.tier ? (
                  <span className="text-[#10b981]">
                    {row.tier}
                    {row.isLifetime ? ' · lifetime' : ''}
                  </span>
                ) : (
                  <span className="text-textColor/40">—</span>
                )}
              </td>
              <td className="py-[10px]">
                {row.timesUsed}
                {row.maxUses ? ` / ${row.maxUses}` : ''}
              </td>
              <td className="py-[10px]">
                <span
                  className={
                    row.active
                      ? 'text-[#10b981]'
                      : 'text-textColor/40 line-through'
                  }
                >
                  {row.active ? 'Active' : 'Inactive'}
                </span>
              </td>
              <td className="py-[10px] text-right">
                <div className="flex gap-[8px] justify-end">
                  <button
                    className="underline text-[13px]"
                    onClick={() => toggle(row)}
                  >
                    {row.active ? 'Disable' : 'Enable'}
                  </button>
                  <button
                    className="underline text-[13px] text-red-400"
                    onClick={() => remove(row)}
                  >
                    Delete
                  </button>
                </div>
              </td>
            </tr>
          ))}
          {!data?.length && (
            <tr>
              <td colSpan={6} className="py-[16px] text-textColor/50">
                No codes yet — add one above.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
};
