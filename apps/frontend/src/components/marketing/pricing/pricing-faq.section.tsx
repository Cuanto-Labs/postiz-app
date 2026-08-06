'use client';

import { useState } from 'react';
import clsx from 'clsx';

type FaqItem = {
  question: string;
  answer: string;
};

const FAQ_ITEMS: FaqItem[] = [
  {
    question: 'What do I get with the free trial?',
    answer:
      'Every new account starts with a 3-month trial of the Standard plan — full access to the channels, scheduling, and AI features included in that tier, at no cost.',
  },
  {
    question: 'What are channels?',
    answer:
      'A channel is a single connected social account you publish to — for example one X account or one Instagram account. Each plan includes a set number of connected channels.',
  },
  {
    question: 'Can I change plans later?',
    answer:
      'Yes. Upgrade, downgrade, or switch between monthly and yearly billing at any time from your account settings — changes apply immediately.',
  },
  {
    question: 'What are team members?',
    answer:
      'Team members are people you invite into your workspace to help manage posts and channels. Plans with team member support allow unlimited invited collaborators.',
  },
  {
    question: 'What is the public API for?',
    answer:
      'The public API lets you schedule and manage posts programmatically from your own tools, scripts, or integrations.',
  },
];

const FaqRow = ({ item }: { item: FaqItem }) => {
  const [open, setOpen] = useState(false);

  return (
    <div
      className="border border-white/10 bg-white/[0.03] rounded-[12px] p-[20px] cursor-pointer select-none"
      onClick={() => setOpen((prev) => !prev)}
    >
      <div className="flex items-center justify-between gap-[16px]">
        <div className="text-[16px] font-[600]">{item.question}</div>
        <div
          className={clsx(
            'shrink-0 text-white/50 text-[20px] leading-none transition-transform duration-200',
            open && 'rotate-45'
          )}
        >
          +
        </div>
      </div>
      <div
        className={clsx(
          'overflow-hidden transition-all duration-300 text-[14px] text-white/60',
          open ? 'max-h-[200px] mt-[12px]' : 'max-h-0'
        )}
      >
        {item.answer}
      </div>
    </div>
  );
};

/**
 * Native FAQ accordion for the pricing page. billing/faq.component.tsx
 * couldn't be reused as-is — it depends on useUser()/useVariables(), which
 * assume an authed context this public page doesn't have.
 */
export const PricingFaqSection = () => {
  return (
    <section className="max-w-[800px] w-full mx-auto px-[24px] pb-[96px]">
      <h2 className="text-[28px] sm:text-[32px] font-[700] text-center mb-[32px]">
        Frequently asked questions
      </h2>
      <div className="flex flex-col gap-[12px]">
        {FAQ_ITEMS.map((item) => (
          <FaqRow key={item.question} item={item} />
        ))}
      </div>
    </section>
  );
};
