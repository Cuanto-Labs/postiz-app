'use client';

import React, { FC, useCallback, useState } from 'react';
import useSWR from 'swr';
import dayjs from 'dayjs';
import { useFetch } from '@gitroom/helpers/utils/custom.fetch';
import { useToaster } from '@gitroom/react/toaster/toaster';
import { Button } from '@gitroom/react/form/button';
import { Input } from '@gitroom/react/form/input';
import { Select } from '@gitroom/react/form/select';
import { Checkbox } from '@gitroom/react/form/checkbox';
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

const useOrganizations = (query: string) => {
  const fetch = useFetch();
  const loader = useCallback(async () => {
    const res = await fetch(
      `/admin/organizations?email=${encodeURIComponent(query)}`
    );
    return res.ok ? ((await res.json()) as OrgRow[]) : ([] as OrgRow[]);
  }, [fetch, query]);

  return useSWR(query.length >= 3 ? `admin-orgs-${query}` : null, loader);
};

const planSummary = (org: OrgRow) => {
  if (!org.subscription) {
    return 'FREE — no subscription';
  }
  const { subscriptionTier, isLifetime, cancelAt } = org.subscription;
  if (isLifetime) {
    return `${subscriptionTier} · lifetime`;
  }
  if (cancelAt) {
    return `${subscriptionTier} · through ${dayjs(cancelAt).format(
      'MMM D, YYYY'
    )}`;
  }
  return `${subscriptionTier} · no end date`;
};

const FieldRow: FC<{ children: React.ReactNode }> = ({ children }) => (
  <div className="flex flex-wrap gap-[12px] items-start">{children}</div>
);

/**
 * Checkboxes render without a label element above them, so they need the same
 * offset the labelled fields get in order to share a line with them.
 */
const CheckboxRow: FC<{ children: React.ReactNode }> = ({ children }) => (
  <div className="flex gap-[20px] items-center h-[42px] mt-[26px]">
    {children}
  </div>
);

const DiffList: FC<{
  title: string;
  color: string;
  mark: string;
  lines: string[];
}> = ({ title, color, mark, lines }) => {
  if (!lines.length) {
    return null;
  }
  return (
    <div className="flex flex-col gap-[6px]">
      <div className="text-[13px] font-[600]" style={{ color }}>
        {title}
      </div>
      {lines.map((line) => (
        <div key={line} className="text-[14px] text-newTextColor/80">
          <span style={{ color }}>{mark}</span> {line}
        </div>
      ))}
    </div>
  );
};

const ChangePlan: FC<{ org: OrgRow; onApplied: () => void }> = ({
  org,
  onApplied,
}) => {
  const fetch = useFetch();
  const toaster = useToaster();

  const [tier, setTier] = useState<Tier>('PRO');
  const [duration, setDuration] = useState('1');
  const [unit, setUnit] = useState<'months' | 'days'>('months');
  const [isLifetime, setIsLifetime] = useState(false);
  const [notify, setNotify] = useState(true);
  const [note, setNote] = useState('');
  const [preview, setPreview] = useState<Preview | null>(null);
  const [busy, setBusy] = useState(false);

  const loadPreview = useCallback(async () => {
    const res = await fetch(
      `/admin/organizations/${org.id}/tier-preview?tier=${tier}`
    );
    if (!res.ok) {
      toaster.show('Could not build a preview for that plan', 'warning');
      return;
    }
    setPreview((await res.json()) as Preview);
  }, [fetch, org.id, tier, toaster]);

  const apply = useCallback(async () => {
    setBusy(true);
    const res = await fetch(`/admin/organizations/${org.id}/tier`, {
      method: 'POST',
      body: JSON.stringify({
        tier,
        isLifetime,
        durationDays:
          !isLifetime && unit === 'days' && duration.trim() !== ''
            ? Number(duration)
            : null,
        durationMonths:
          !isLifetime && unit === 'months' && duration.trim() !== ''
            ? Number(duration)
            : null,
        notify,
        reason: note.trim() || undefined,
      }),
    });
    setBusy(false);

    if (!res.ok) {
      toaster.show((await res.text()) || 'Could not apply that plan', 'warning');
      return;
    }

    toaster.show(
      notify
        ? `${tier} applied — the customer has been emailed`
        : `${tier} applied — no email sent`,
      'success'
    );
    setPreview(null);
    onApplied();
  }, [
    fetch,
    org.id,
    tier,
    isLifetime,
    unit,
    duration,
    notify,
    note,
    toaster,
    onApplied,
  ]);

  if (org.paymentId) {
    return (
      <div className="bg-newColColor rounded-[8px] p-[16px] text-[14px] text-newTextColor/80">
        This organization pays through Stripe (customer{' '}
        <span className="text-newTextColor">{org.paymentId}</span>). Change the
        plan in Stripe — a manual change here would be overwritten by the next
        webhook.
      </div>
    );
  }

  return (
    <div className="bg-newColColor rounded-[8px] p-[20px] flex flex-col gap-[18px]">
      <FieldRow>
        <div className="w-[170px]">
          <Select
            label="New plan"
            translationKey="label_new_plan"
            name="tier"
            disableForm={true}
            hideErrors={true}
            value={tier}
            onChange={(e) => {
              setTier(e.target.value as Tier);
              setPreview(null);
            }}
          >
            {TIERS.map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-[160px]">
          <Input
            label="Lasts"
            translationKey="label_lasts"
            name="duration"
            disableForm={true}
            removeError={true}
            inputMode="numeric"
            placeholder="forever"
            disabled={isLifetime}
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
            disabled={isLifetime}
            value={unit}
            onChange={(e) => setUnit(e.target.value as 'months' | 'days')}
          >
            {/* Months keep the day-of-month (19 Aug → 19 Sep); days cannot,
                because month lengths differ. */}
            <option value="months">months</option>
            <option value="days">days</option>
          </Select>
        </div>

        <CheckboxRow>
          <Checkbox
            name="isLifetime"
            disableForm={true}
            label="Lifetime"
            checked={isLifetime}
            onChange={(e) => {
              setIsLifetime(e.target.value);
              if (e.target.value) {
                setDuration('');
              }
              setPreview(null);
            }}
          />
          <Checkbox
            name="notify"
            disableForm={true}
            label="Email the customer"
            checked={notify}
            onChange={(e) => setNotify(e.target.value)}
          />
        </CheckboxRow>
      </FieldRow>

      <Input
        label="Note for the customer (optional — appears in the email)"
        translationKey="label_customer_note"
        name="note"
        disableForm={true}
        removeError={true}
        placeholder="Applied as agreed on your call with us."
        value={note}
        onChange={(e) => setNote(e.target.value)}
      />

      <div className="flex gap-[10px] items-center flex-wrap">
        <Button secondary onClick={loadPreview} disabled={busy}>
          Preview changes
        </Button>
        <Button onClick={apply} disabled={busy || !preview}>
          {busy ? 'Applying…' : 'Apply plan'}
        </Button>
        {!preview && (
          <span className="text-[13px] text-newTextColor/40">
            Preview first — it is exactly what the customer will be told.
          </span>
        )}
      </div>

      {!!preview && (
        <div className="flex flex-col gap-[14px] border-t border-newTableBorder pt-[16px]">
          <div className="text-[14px] text-newTextColor/70">
            {preview.from || 'FREE'} →{' '}
            <span className="text-newTextColor font-[600]">{preview.to}</span>
          </div>

          <DiffList title="Gains" color="#10b981" mark="+" lines={preview.added} />
          <DiffList title="Loses" color="#f87171" mark="−" lines={preview.removed} />

          {!!preview.removed.length && (
            <div className="text-[13px] text-newTextColor/40">
              Channels over the new limit are disabled, not deleted — they come
              back on an upgrade.
            </div>
          )}

          {!preview.added.length && !preview.removed.length && (
            <div className="text-[14px] text-newTextColor/50">
              No feature differences — that is the plan they already have.
            </div>
          )}
        </div>
      )}
    </div>
  );
};

const OrganizationCard: FC<{ org: OrgRow; onApplied: () => void }> = ({
  org,
  onApplied,
}) => {
  const [open, setOpen] = useState(false);

  return (
    <div className="bg-newBgColorInner rounded-[8px] p-[20px] flex flex-col gap-[16px]">
      <div className="flex justify-between items-start gap-[16px] flex-wrap">
        <div className="flex flex-col gap-[6px]">
          <div className="text-[16px] font-[600]">{org.name}</div>
          <div className="text-[14px] text-newTextColor/60">
            {org.users.map((member) => member.user.email).join(', ')}
          </div>
          <div className="text-[14px] text-newTextColor/60">
            {planSummary(org)} · {org._count.Integration}{' '}
            {org._count.Integration === 1 ? 'channel' : 'channels'} connected
            {org.isTrailing ? ' · on trial' : ''}
          </div>
        </div>

        <Button secondary onClick={() => setOpen(!open)}>
          {open ? 'Close' : 'Change plan'}
        </Button>
      </div>

      {open && <ChangePlan org={org} onApplied={onApplied} />}
    </div>
  );
};

export const AdminTierComponent = () => {
  const [emailInput, setEmailInput] = useState('');
  const [query, setQuery] = useState('');
  const { data, isLoading, mutate } = useOrganizations(query);

  const search = useCallback(() => setQuery(emailInput.trim()), [emailInput]);

  return (
    <div className="flex flex-col gap-[20px]">
      <div className="text-[20px] font-[700]">Plan changes</div>
      <div className="text-[14px] text-newTextColor/70 max-w-[760px]">
        Apply a plan to a customer by hand. This runs through the same path as a
        redeemed code, so the same limits are enforced and the same email is
        sent. Organizations billed through Stripe are read-only here.
      </div>

      <div className="bg-newBgColorInner rounded-[8px] p-[20px]">
        <FieldRow>
          <div className="flex-1 min-w-[260px]">
            <Input
              label="Customer email"
              translationKey="label_customer_email"
              name="email"
              disableForm={true}
              removeError={true}
              placeholder="name@example.com"
              value={emailInput}
              onChange={(e) => setEmailInput(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && search()}
            />
          </div>
          <div className="mt-[26px]">
            <Button onClick={search} disabled={emailInput.trim().length < 3}>
              Search
            </Button>
          </div>
        </FieldRow>
      </div>

      {isLoading && <LoadingComponent />}

      {!isLoading && !!query && !data?.length && (
        <div className="text-[14px] text-newTextColor/50">
          No organizations found for “{query}”.
        </div>
      )}

      <div className="flex flex-col gap-[12px]">
        {(data || []).map((org) => (
          <OrganizationCard key={org.id} org={org} onApplied={() => mutate()} />
        ))}
      </div>
    </div>
  );
};
