import type { MetadataRoute } from 'next';

const BASE_URL = 'https://socials.cuantolabs.com';

// Public marketing/legal surfaces are crawlable; everything behind auth
// (app shell, settings, billing, messages, analytics, launches) and internal
// routes (API, oauth callbacks, upload/media proxies) are not.
export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: '*',
      allow: ['/', '/home', '/pricing', '/join/', '/terms', '/privacy'],
      disallow: [
        '/api/',
        '/auth/',
        '/launches',
        '/analytics',
        '/settings',
        '/billing',
        '/messages',
        '/integrations/',
        '/oauth/',
        '/p/',
        '/modal/',
        '/uploads/',
      ],
    },
    sitemap: `${BASE_URL}/sitemap.xml`,
  };
}
