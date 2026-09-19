# VISION — Cuanto Socials SaaS distribution readiness

**Repo:** `C:\Users\elira\coding\cuanto-socials-postiz` (Postiz fork, pnpm monorepo, Next.js frontend + NestJS backend + Temporal orchestrator)
**Branch:** `autopilot/saas-launch` (cut from `dev`; `dev`/`staging` created off `main` per fleet branch model)
**External writes:** GRANTED by Eliran 2026-07-30 ("deploy latest versions to main and make sure updates on vercel and railways"). Scope: push to `cuantolabs` remote (github.com/Cuanto-Labs/cuanto-socials) ONLY — NEVER push to `origin` (upstream gitroomhq/postiz-app) — plus Vercel/deb deploy verification. Promotion path per fleet rule: autopilot branch → dev → staging → main, merges not force-push. Deploy = M8, runs LAST after build missions.

## Goal

Make the app distributable as B2C and B2B SaaS: public marketing landing site, public pricing,
working acquisition funnel (landing → join campaigns → signup), brand/SEO polish on public
surfaces, and a documented go-live checklist covering the known env gaps.

## Definition of Done (objective, observable)

1. Gate command `pnpm run verify` exists at repo root and exits 0 (M0).
2. A logged-out visitor to `/` is served a marketing landing page — NOT redirected to `/auth`.
   Authed visitors to `/` still land on `/launches`. Evidence: proxy.ts allow-list + page route
   + screenshot.
3. A logged-out visitor to `/join/<campaign>` reaches the campaign landing page (today the
   proxy bounces them to `/auth` and drops the invite — bug). Evidence: proxy.ts change.
4. Public `/pricing` page renders tiers imported from
   `libraries/nestjs-libraries/src/database/prisma/subscriptions/pricing.ts` (single source,
   no duplicated numbers), CTA → `/auth`.
5. Landing page has distinct B2C ("creators") and B2B ("agencies & teams") sections linking to
   `/join/creators` and `/join/agencies`.
6. Public pages (/, /pricing, /join/*) export metadata (title/description/OG); no user-visible
   "Postiz" branding on any public page.
7. `docs/LAUNCH-CHECKLIST.md` documents the go-live env matrix incl. known gaps:
   STRIPE_SIGNING_KEY missing on deb, X_API_KEY/X_API_SECRET missing while `x` enabled,
   MCP_URL missing on Vercel, STRIPE_PUBLISHABLE_KEY presence = billing on/off switch.
8. Desktop + mobile screenshots of landing + pricing captured (fleet verification standard).

## Gate

No working test/typecheck exists (zero test files; root jest config imports missing @nx/jest;
no typecheck/lint scripts). **M0 builds the gate:** root script `verify` =
`prisma validate` (schema smoke) + `tsc --noEmit -p apps/frontend/tsconfig.json`
(frontend tsconfig already sets noEmit and pulls in libraries via path aliases).
`tsgo` NOT installed on this PC — use repo-local tsc via pnpm. If frontend tsc has
pre-existing unrelated errors, gate may pin a baseline (error count must not grow) — but
prefer clean 0.

## Non-goals (v1)

- White-label/theming support (no NEXT_PUBLIC_APP_NAME exists; B2B v1 ships without it)
- Setting real Stripe/X/MCP env values or any deploy (external — checklist documents them)
- New social providers; testing live Stripe flows; i18n of marketing pages
- Building a test suite beyond the gate; fixing the broken root jest/@nx config
- Renaming package `gitroom` / `@gitroom/*` import aliases (internal, not user-visible)

## Assumptions (senior-engineer, recorded not asked)

- "This social sharing smart ai web app" = this repo (session dir `social-automations` is an
  empty stub; memory confirms cuanto-socials is the product).
- Marketing site lives INSIDE `apps/frontend` as public routes (same Vercel project, shares
  auth CTA and proxy) — not a separate repo/app.
- Brand: "Cuanto Socials" by Cuanto Labs, accents `#10b981` green / `#6366f1` indigo
  (existing logo-text.component.tsx palette). Dark theme like existing /join pages.
- Pricing shown publicly = tiers already coded in pricing.ts (STANDARD $29, TEAM $39, PRO $49,
  ULTIMATE $99; free tier = 3-month STANDARD grant).
