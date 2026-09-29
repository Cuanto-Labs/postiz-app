'use client';

import React, { FC, useCallback, useState } from 'react';
import useSWR from 'swr';
import { useFetch } from '@gitroom/helpers/utils/custom.fetch';
import { useToaster } from '@gitroom/react/toaster/toaster';
import { Button } from '@gitroom/react/form/button';
import { Input } from '@gitroom/react/form/input';
import { Select } from '@gitroom/react/form/select';
import { Checkbox } from '@gitroom/react/form/checkbox';
import { LoadingComponent } from '@gitroom/frontend/components/layout/loading';

type Tier = 'STANDARD' | 'TEAM' | 'PRO' | 'ULTIMATE';

// Mirrors the Prisma enum, which has no FREE — free is the absence of a
// subscription, not a tier a code can grant.
const TIERS: Tier[] = ['STANDARD', 'TEAM', 'PRO', 'ULTIMATE'];

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
  durationDays: number | null;
  durationMonths: number | null;
  createdAt: string;
}

const FieldRow: FC<{ children: React.ReactNode }> = ({ children }) => (
  <div className="flex flex-wrap gap-[12px] items-start">{children}</div>
);

/** Checkboxes have no label element above them, so they need the labelled
 *  fields' offset to share a line with them. */
const CheckboxRow: FC<{ children: React.ReactNode }> = ({ children }) => (
  <div className="flex gap-[20px] items-center h-[42px] mt-[26px]">
    {children}
  </div>
);

/** What a code grants, in one cell. */
const Grants: FC<{ row: InviteCode }> = ({ row }) => {
  if (!row.tier) {
    return <span className="text-newTextColor/40">Attribution only</span>;
  }

  const validity = row.isLifetime
    ? 'lifetime'
    : row.durationMonths
    ? `${row.durationMonths} ${row.durationMonths === 1 ? 'month' : 'months'}`
    : row.durationDays
    ? `${row.durationDays} ${row.durationDays === 1 ? 'day' : 'days'}`
    : 'no end date';

  return (
    <span className="text-[#10b981]">
      {row.tier} · {validity}
    </span>
  );
};

const useInviteCodes = () => {
  const fetch = useFetch();
  const loader = useCallback(async () => {
    const res = await fetch('/admin/invite-codes');
    return res.ok ? ((await res.json()) as InviteCode[]) : ([] as InviteCode[]);
  }, [fetch]);

  return useSWR('admin-invite-codes', loader);
};

const CreateCode: FC<{ onCreated: () => void }> = ({ onCreated }) => {
  const fetch = useFetch();
  const toaster = useToaster();

  const [code, setCode] = useState('');
  const [label, setLabel] = useState('');
  const [tier, setTier] = useState<Tier | ''>('');
  const [duration, setDuration] = useState('');
  const [unit, setUnit] = useState<'months' | 'days'>('months');
  const [isLifetime, setIsLifetime] = useState(false);
  const [maxUses, setMaxUses] = useState('');
  const [busy, setBusy] = useState(false);

  const create = useCallback(async () => {
    setBusy(true);
    const res = await fetch('/admin/invite-codes', {
      method: 'POST',
      body: JSON.stringify({
        code: code.trim(),
        label: label.trim(),
        tier: tier || null,
        isLifetime,
        maxUses: maxUses.trim() === '' ? null : Number(maxUses),
        durationDays:
          !isLifetime && unit === 'days' && duration.trim() !== ''
            ? Number(duration)
            : null,
        durationMonths:
          !isLifetime && unit === 'months' && duration.trim() !== ''
            ? Number(duration)
            : null,
      }),
    });
    setBusy(false);

    if (!res.ok) {
      toaster.show((await res.text()) || 'Could not save that code', 'warning');
      return;
    }

    toaster.show(`${code.trim()} created`, 'success');
    setCode('');
    setLabel('');
    setTier('');
    setDuration('');
    setIsLifetime(false);
    setMaxUses('');
    onCreated();
  }, [
    fetch,
    code,
    label,
    tier,
    duration,
    unit,
    isLifetime,
    maxUses,
    toaster,
    onCreated,
  ]);

  return (
    <div className="bg-newBgColorInner rounded-[8px] p-[20px] flex flex-col gap-[18px]">
      <FieldRow>
        <div className="w-[190px]">
          <Input
            label="Code"
            translationKey="label_code"
            name="code"
            disableForm={true}
            removeError={true}
            placeholder="LAUNCH"
            value={code}
            onChange={(e) => setCode(e.target.value.toUpperCase())}
          />
        </div>

        <div className="flex-1 min-w-[220px]">
          <Input
            label="Label (optional)"
            translationKey="label_code_label"
            name="label"
            disableForm={true}
            removeError={true}
            placeholder="Spring launch campaign"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
          />
        </div>

        <div className="w-[210px]">
          <Select
            label="Grants plan"
            translationKey="label_grants_plan"
            name="tier"
            disableForm={true}
            hideErrors={true}
            value={tier}
            onChange={(e) => {
              const next = e.target.value as Tier | '';
              setTier(next);
              if (!next) {
                setIsLifetime(false);
                setDuration('');
              }
            }}
          >
            <option value="">None — attribution only</option>
            {TIERS.map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </Select>
        </div>
      </FieldRow>

      <FieldRow>
        <div className="w-[160px]">
          <Input
            label="Lasts"
            translationKey="label_lasts"
            name="duration"
            disableForm={true}
            removeError={true}
            inputMode="numeric"
            placeholder="forever"
            disabled={!tier || isLifetime}
            value={duration}
            onChange={(e) => setDuration(e.target.value.replace(/[^0-9]/g, ''))}
          />
        </div>

        <div className="w-[160px]">
          <Select
            label="Unit"
            translationKey="label_unit"
            name="unit"
            disableForm={true}
            hideErrors={true}
            disabled={!tier || isLifetime}
            value={unit}
            onChange={(e) => setUnit(e.target.value as 'months' | 'days')}
          >
            {/* Months keep the day-of-month (19 Aug → 19 Sep); days cannot,
                because month lengths differ. */}
            <option value="months">months</option>
            <option value="days">days</option>
          </Select>
        </div>

        <div className="w-[160px]">
          <Input
            label="Max uses"
            translationKey="label_max_uses"
            name="maxUses"
            disableForm={true}
            removeError={true}
            inputMode="numeric"
            placeholder="unlimited"
            value={maxUses}
            onChange={(e) => setMaxUses(e.target.value.replace(/[^0-9]/g, ''))}
          />
        </div>

        <CheckboxRow>
          <Checkbox
            name="isLifetime"
            disableForm={true}
            label="Lifetime"
            checked={isLifetime}
            onChange={(e) => {
              setIsLifetime(e.target.value);
              // Lifetime and a duration are mutually exclusive — the backend
              // ignores duration when lifetime is set, so the form should not
              // imply otherwise.
              if (e.target.value) {
                setDuration('');
              }
            }}
          />
        </CheckboxRow>

        <div className="mt-[26px]">
          <Button onClick={create} disabled={busy || !code.trim()}>
            {busy ? 'Saving…' : 'Add code'}
          </Button>
        </div>
      </FieldRow>
    </div>
  );
};

const CodeRow: FC<{ row: InviteCode; onChanged: () => void }> = ({
  row,
  onChanged,
}) => {
  const fetch = useFetch();
  const toaster = useToaster();

  const toggle = useCallback(async () => {
    await fetch(`/admin/invite-codes/${row.id}`, {
      method: 'PUT',
      body: JSON.stringify({ active: !row.active }),
    });
    toaster.show(
      `${row.code} ${row.active ? 'disabled' : 'enabled'}`,
      'success'
    );
    onChanged();
  }, [fetch, row, toaster, onChanged]);

  const remove = useCallback(async () => {
    if (!window.confirm(`Delete code "${row.code}"?`)) {
      return;
    }
    await fetch(`/admin/invite-codes/${row.id}`, { method: 'DELETE' });
    toaster.show(`${row.code} deleted`, 'success');
    onChanged();
  }, [fetch, row, toaster, onChanged]);

  return (
    <tr className="border-b border-newTableBorder">
      <td className="py-[12px] font-[600]">{row.code}</td>
      <td className="py-[12px] text-newTextColor/70">{row.label || '—'}</td>
      <td className="py-[12px]">
        <Grants row={row} />
      </td>
      <td className="py-[12px]">
        {row.timesUsed}
        {row.maxUses ? ` / ${row.maxUses}` : ''}
      </td>
      <td className="py-[12px]">
        <span
          className={
            row.active ? 'text-[#10b981]' : 'text-newTextColor/40 line-through'
          }
        >
          {row.active ? 'Active' : 'Inactive'}
        </span>
      </td>
      <td className="py-[12px]">
        <div className="flex gap-[8px] justify-end">
          <Button secondary onClick={toggle}>
            {row.active ? 'Disable' : 'Enable'}
          </Button>
          <Button secondary onClick={remove}>
            Delete
          </Button>
        </div>
      </td>
    </tr>
  );
};

export const AdminCodesComponent = () => {
  const { data, isLoading, mutate } = useInviteCodes();

  if (isLoading) {
    return <LoadingComponent />;
  }

  return (
    <div className="flex flex-col gap-[20px]">
      <div className="text-[20px] font-[700]">Invite codes</div>
      <div className="text-[14px] text-newTextColor/70 max-w-[820px]">
        Codes carried by landing pages as{' '}
        <code className="bg-newColColor px-[6px] py-[2px] rounded-[4px]">
          /join/&lt;page&gt;
        </code>{' '}
        and forwarded to registration as{' '}
        <code className="bg-newColColor px-[6px] py-[2px] rounded-[4px]">
          ?invite=CODE
        </code>
        . Registration is open without a code. A code with no plan is
        attribution only; give it a plan and it grants that plan — at signup, or
        redeemed later at{' '}
        <code className="bg-newColColor px-[6px] py-[2px] rounded-[4px]">
          /billing/redeem
        </code>
        . An inactive, expired, or fully-used code is rejected.
      </div>

      <CreateCode onCreated={() => mutate()} />

      <table className="w-full text-[14px]">
        <thead>
          <tr className="text-left text-newTextColor/60 border-b border-newTableBorder">
            <th className="py-[10px]">Code</th>
            <th className="py-[10px]">Label</th>
            <th className="py-[10px]">Grants</th>
            <th className="py-[10px]">Uses</th>
            <th className="py-[10px]">Status</th>
            <th className="py-[10px]" />
          </tr>
        </thead>
        <tbody>
          {(data || []).map((row) => (
            <CodeRow key={row.id} row={row} onChanged={() => mutate()} />
          ))}
          {!data?.length && (
            <tr>
              <td colSpan={6} className="py-[16px] text-newTextColor/50">
                No codes yet — add one above.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
};
