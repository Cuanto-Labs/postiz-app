/**
 * Themed acquisition landing pages, one per campaign slug, served at
 * /join/<slug>. Each carries its own `invite` code — the CTA forwards it as
 * /auth?invite=<code>, the register form prefills it and never shows the code
 * field, and the backend validates it against the REGISTRATION_CODE allow-list.
 *
 * For a code here to pass registration it must appear in the backend's
 * REGISTRATION_CODE (comma-separated). Keep the two in sync — an unregistered
 * code 403s at signup.
 */
export type Campaign = {
  slug: string;
  invite: string;
  eyebrow: string;
  headline: string;
  accentWord: string;
  subhead: string;
  bullets: string[];
  cta: string;
  accent: string;
};

export const CAMPAIGNS: Record<string, Campaign> = {
  creators: {
    slug: 'creators',
    invite: 'CREATORS',
    eyebrow: 'For creators',
    headline: 'Post everywhere,',
    accentWord: 'from one place.',
    subhead:
      'Write once, let AI draft the rest, and keep every channel on a single calendar. Your first months are on us.',
    bullets: [
      'AI writes the post and generates the image',
      'Schedule ahead across every channel',
      'One calendar for everything you publish',
    ],
    cta: 'Start creating free',
    accent: '#10b981',
  },
  agencies: {
    slug: 'agencies',
    invite: 'AGENCIES',
    eyebrow: 'For agencies & teams',
    headline: 'Run every client',
    accentWord: 'in one workspace.',
    subhead:
      'Draft, schedule and track posts for all your clients together — with AI doing the first pass. Free while you get set up.',
    bullets: [
      'Manage multiple brands side by side',
      'AI-assisted drafting for faster turnaround',
      'Shared calendar and post history per client',
    ],
    cta: 'Get started free',
    accent: '#6366f1',
  },
  launch: {
    slug: 'launch',
    invite: 'LAUNCH',
    eyebrow: 'Launch offer',
    headline: 'Your social calendar,',
    accentWord: 'handled.',
    subhead:
      'Schedule and publish to 28+ channels, with AI text and images built in. Sign up now and the next tier is free.',
    bullets: [
      'Publish to 28+ social and chat channels',
      'AI text and image generation included',
      'No card required to get started',
    ],
    cta: 'Claim your free access',
    accent: '#10b981',
  },
};

export const getCampaign = (slug: string): Campaign | undefined =>
  CAMPAIGNS[slug?.toLowerCase()];
