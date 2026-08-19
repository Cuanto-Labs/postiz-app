// Brand substitution for upstream-shipped strings.
//
// Upstream (gitroomhq/postiz-app) bakes the product name into every user-facing
// string, including all 14 locale files. This fork used to rebrand them in place,
// which is why a v2.23.0 merge dry-run conflicted in 20 files — 14 of them locale
// JSONs whose ONLY divergence was "Postiz" -> "Cuanto Socials" (verified: 14
// changed lines per file, zero of them anything else).
//
// Substituting at load time instead means:
//   - the locale files stay byte-identical to upstream, so they fast-forward on
//     every future merge instead of conflicting;
//   - strings upstream ADDS later get rebranded automatically, with no follow-up.
//
// Only the capitalised product name is replaced. Lowercase "postiz" appears in
// translation KEYS and in upstream URLs (postiz.com, the N8N node id), which must
// keep working, so it is deliberately left alone.
export const BRAND_NAME = process.env.NEXT_PUBLIC_BRAND_NAME || 'Cuanto Socials';

const UPSTREAM_NAME = /Postiz/g;

export function brandString(value: string): string {
  return value.includes('Postiz') ? value.replace(UPSTREAM_NAME, BRAND_NAME) : value;
}

// Walks a loaded translation namespace and rebrands every string value. Runs once
// per (language, namespace) at load, not per lookup.
export function applyBrand<T>(resources: T): T {
  if (typeof resources === 'string') {
    return brandString(resources) as unknown as T;
  }
  if (Array.isArray(resources)) {
    return resources.map((item) => applyBrand(item)) as unknown as T;
  }
  if (resources && typeof resources === 'object') {
    const out: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(resources as Record<string, unknown>)) {
      out[key] = applyBrand(value);
    }
    return out as unknown as T;
  }
  return resources;
}
