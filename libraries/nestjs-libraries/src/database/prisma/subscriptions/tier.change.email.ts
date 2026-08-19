import dayjs from 'dayjs';
import { describeTierChange } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/tier.diff';

export interface TierChangeEmailInput {
  from: string | null;
  to: string;
  isLifetime: boolean;
  /** Null means the plan has no end date. */
  expiresAt: Date | null;
  /** Set when an operator made the change rather than a redeemed code. */
  reason?: string;
}

const ACCENT = '#10b981';
const MUTED = '#6b7280';

// EmailService wraps this in the branded shell (heading, footer, preferences
// link), so this builds the body only — no <html>, no closing signature.
const list = (items: string[], color: string, mark: string) =>
  items
    .map(
      (item) => `
  <tr>
    <td style="padding: 4px 0; vertical-align: top; width: 20px; color: ${color}; font-weight: 700;">${mark}</td>
    <td style="padding: 4px 0; color: #374151;">${item}</td>
  </tr>`
    )
    .join('');

export const tierChangeSubject = (input: TierChangeEmailInput) => {
  const { added, removed } = describeTierChange(input.from, input.to);
  const downgrade = removed.length > 0 && added.length === 0;
  return downgrade
    ? `Your plan has changed to ${input.to}`
    : `You're now on ${input.to}`;
};

export const tierChangeEmailHtml = (input: TierChangeEmailInput) => {
  const { added, removed } = describeTierChange(input.from, input.to);

  const validity = input.isLifetime
    ? 'This plan does not expire.'
    : input.expiresAt
    ? `This plan runs through <strong>${dayjs(input.expiresAt).format(
        'MMMM D, YYYY'
      )}</strong>.`
    : 'This plan has no end date.';

  const movement = input.from
    ? `<p style="margin: 0 0 16px;">Your workspace has moved from <strong>${input.from}</strong> to <strong style="color: ${ACCENT};">${input.to}</strong>.</p>`
    : `<p style="margin: 0 0 16px;">Your workspace is now on <strong style="color: ${ACCENT};">${input.to}</strong>.</p>`;

  return `
${movement}
<p style="margin: 0 0 20px; color: ${MUTED}; font-size: 14px;">${validity}${
    input.reason
      ? ` ${input.reason}`
      : ''
  }</p>

${
  added.length
    ? `<p style="margin: 0 0 6px; font-weight: 600;">What's included now</p>
<table style="border-collapse: collapse; margin: 0 0 20px; width: 100%;">${list(
        added,
        ACCENT,
        '+'
      )}</table>`
    : ''
}

${
  removed.length
    ? `<p style="margin: 0 0 6px; font-weight: 600;">No longer included</p>
<table style="border-collapse: collapse; margin: 0 0 20px; width: 100%;">${list(
        removed,
        '#b91c1c',
        '−'
      )}</table>
<p style="margin: 0 0 20px; color: ${MUTED}; font-size: 13px;">Channels beyond your new limit are disabled rather than deleted — they come back if you move up again.</p>`
    : ''
}

<a
  href="${process.env.FRONTEND_URL}/billing"
  style="
    display: inline-block;
    background: ${ACCENT};
    color: #ffffff;
    font-weight: 600;
    text-decoration: none;
    padding: 12px 28px;
    border-radius: 10px;
    margin: 4px 0 8px;
  "
>View your plan</a>
`;
};
