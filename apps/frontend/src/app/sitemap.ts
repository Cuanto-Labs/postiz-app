import type { MetadataRoute } from 'next';
import { CAMPAIGNS } from '@gitroom/frontend/components/landing/campaigns';

const BASE_URL = 'https://socials.cuantolabs.com';

// Public routes only — authed app routes (/launches, /analytics, /settings,
// /billing, /messages) are intentionally excluded, same allow-list as
// proxy.ts and robots.ts.
export default function sitemap(): MetadataRoute.Sitemap {
  const staticRoutes: MetadataRoute.Sitemap = [
    { url: `${BASE_URL}/`, changeFrequency: 'weekly', priority: 1 },
    { url: `${BASE_URL}/home`, changeFrequency: 'weekly', priority: 1 },
    { url: `${BASE_URL}/pricing`, changeFrequency: 'weekly', priority: 0.8 },
    { url: `${BASE_URL}/terms`, changeFrequency: 'monthly', priority: 0.3 },
    { url: `${BASE_URL}/privacy`, changeFrequency: 'monthly', priority: 0.3 },
  ];

  const campaignRoutes: MetadataRoute.Sitemap = Object.keys(CAMPAIGNS).map(
    (slug) => ({
      url: `${BASE_URL}/join/${slug}`,
      changeFrequency: 'weekly',
      priority: 0.6,
    })
  );

  return [...staticRoutes, ...campaignRoutes];
}
