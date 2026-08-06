/**
 * /pricing — public pricing page, reachable logged-out (see proxy.ts
 * allow-list). Every price/limit rendered comes from the `pricing` source
 * of truth; see pricing-page.tsx.
 */
import type { Metadata } from 'next';
import { PricingPage } from '@gitroom/frontend/components/marketing/pricing-page';

const TITLE = 'Pricing — Cuanto Socials';
const DESCRIPTION =
  'Simple, transparent pricing for AI-powered social media scheduling. Compare channels, AI image/video credits, team seats, and API access across every plan.';

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  openGraph: {
    title: TITLE,
    description: DESCRIPTION,
    url: 'https://socials.cuantolabs.com/pricing',
    siteName: 'Cuanto Socials',
    type: 'website',
  },
};

export default function Pricing() {
  return <PricingPage />;
}
