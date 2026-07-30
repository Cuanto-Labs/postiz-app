/**
 * /home — public marketing landing page.
 *
 * Logged-out visitors hitting `/` are rewritten here by the proxy (see
 * proxy.ts) so the URL bar still shows `/`; this route is also directly
 * reachable and allow-listed for both logged-out and authed visitors.
 */
import type { Metadata } from 'next';
import { MarketingPage } from '@gitroom/frontend/components/marketing/marketing-page';

const TITLE = 'Cuanto Socials — AI-powered social media management';
const DESCRIPTION =
  'Plan, create, and publish everywhere with AI. Cross-channel scheduling, AI post/image/video generation, an AI copilot, analytics, and team workspaces — for creators and agencies.';

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  openGraph: {
    title: TITLE,
    description: DESCRIPTION,
    url: 'https://socials.cuantolabs.com',
    siteName: 'Cuanto Socials',
    type: 'website',
  },
};

export default function HomePage() {
  return <MarketingPage />;
}
