# Launch Checklist — Cuanto Socials Go-Live

Ops checklist for running this fork as production SaaS. Env var **names** only —
no values. Rotate/set actual secrets via Vercel/Railway dashboards or vault, never
inline in this repo.

---

## Env matrix

Layer legend: **FE** = Vercel frontend (`apps/frontend`), **BE** = Railway backend
(`apps/backend` + `apps/orchestrator`, single service per `railway.toml`).

### Core / infra

| Var | Layer | Required | Notes |
|---|---|---|---|
| `DATABASE_URL` | BE | Required | Postgres (Neon). `preDeployCommand` runs `prisma-db-push` on every deploy. |
| `REDIS_URL` | BE | Required | Queue/cache backing. |
| `TEMPORAL_ADDRESS` | BE | Required | Temporal Cloud endpoint; `start.sh` pre-resolves DNS via DoH (Railway resolver breaks on Temporal Cloud hostnames). |
| `RUN_ORCHESTRATOR_IN_PROCESS` | BE | Optional | `true` = single process hosts API + Temporal workers; unset = two forked processes (backend + orchestrator). |
| `BACKEND_HEAP_MB` / `ORCHESTRATOR_HEAP_MB` | BE | Optional | `--max-old-space-size` per process; defaults 448 / 320. |
| `JWT_SECRET` | BE + FE | Required | Must match across both layers (auth cookie verification). |
| `FRONTEND_URL` | BE + FE | Required | Canonical site origin; used for cookie domain scoping and email links. |
| `NEXT_PUBLIC_BACKEND_URL` | FE | Required | Public API base the browser calls; `vercel.json` rewrites `/api/*` → `https://api.socials.cuantolabs.com/*`. |
| `BACKEND_INTERNAL_URL` | BE | Required | Server-to-server base URL (proxy `internalFetch`, `/user/join-org` etc.). |
| `MAIN_URL` | BE + FE | Required | Legacy/general site URL var, still read directly in layout. |
| `IS_GENERAL` | FE + BE | Optional | Self-host/general-mode flag; drives `/` redirect target (`/launches` vs `/analytics`) and a few feature toggles. |
| `NOT_SECURED` | FE | Optional | Dev-only — disables `secure`/`httpOnly` cookie flags. Must be unset in production. |
| `DISABLE_REGISTRATION` | FE | Optional | `'true'` blocks `/auth/register`, redirects to login. |

### Billing (Stripe) — see "Billing switch" below

| Var | Layer | Required | Notes |
|---|---|---|---|
| `STRIPE_PUBLISHABLE_KEY` | FE + BE | **Required for paid mode** | Presence is the billing master switch — see below. |
| `STRIPE_SECRET_KEY` | BE | Required for paid mode | Falls back to a dummy `sk_nothing` if unset (`stripe.service.ts`). |
| `STRIPE_SIGNING_KEY` | BE | Required for paid mode | Webhook signature verification (`stripe.controller.ts`). **Currently MISSING on Railway — see Known gaps.** |
| `STRIPE_SIGNING_KEY_CONNECT` | BE | Optional | Stripe Connect webhook variant (marketplace/payout path, dormant feature). |
| `FEE_AMOUNT` | BE | Optional | Marketplace/take-rate fee fraction. |
| `FREE_GRANT_MONTHS` *(not an env var)* | BE | N/A | Hardcoded const in `free.tier.ts:10` (currently `3`) — months of free `STANDARD`-tier grant for new orgs. Change requires a code edit, not a Railway env var. |

### Social provider credentials (only needed for providers actually enabled)

| Var | Layer | Required | Notes |
|---|---|---|---|
| `ENABLED_INTEGRATIONS` | BE | Optional | Comma-separated allow-list of provider IDs to activate (e.g. `x,linkedin,linkedin-page`). Unset = all providers active. |
| `X_API_KEY` / `X_API_SECRET` | BE | Required if `x` enabled | Used by every X provider method (post, refresh, OAuth signing). **Currently MISSING on Railway while `x` is enabled — see Known gaps.** |
| `X_URL` | BE | Optional | X callback base override; falls back to `FRONTEND_URL`. |
| `LINKEDIN_CLIENT_ID` / `LINKEDIN_CLIENT_SECRET` | BE | Required if LinkedIn enabled | |
| `FACEBOOK_APP_ID` / `FACEBOOK_APP_SECRET` | BE | Required if Facebook/Threads enabled | |
| `THREADS_APP_ID` / `THREADS_APP_SECRET` | BE | Required if Threads enabled | |
| `YOUTUBE_CLIENT_ID` / `YOUTUBE_CLIENT_SECRET` | BE | Required if YouTube enabled | |
| `TIKTOK_CLIENT_ID` / `TIKTOK_CLIENT_SECRET` | BE | Required if TikTok enabled | |
| `PINTEREST_CLIENT_ID` / `PINTEREST_CLIENT_SECRET` | BE | Required if Pinterest enabled | |
| `REDDIT_CLIENT_ID` / `REDDIT_CLIENT_SECRET` | BE | Required if Reddit enabled | |
| `DISCORD_CLIENT_ID` / `DISCORD_CLIENT_SECRET` / `DISCORD_BOT_TOKEN_ID` | BE | Required if Discord enabled | |
| `SLACK_ID` / `SLACK_SECRET` / `SLACK_SIGNING_SECRET` | BE | Required if Slack enabled | |
| `MASTODON_URL` / `MASTODON_CLIENT_ID` / `MASTODON_CLIENT_SECRET` | BE | Required if Mastodon enabled | |
| `DRIBBBLE_CLIENT_ID` / `DRIBBBLE_CLIENT_SECRET` | BE | Required if Dribbble enabled | |
| `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` | BE | Required if GitHub integration or GitHub-style OAuth login used | |
| `BEEHIIVE_API_KEY` / `BEEHIIVE_PUBLICATION_ID` | BE | Required if Beehiiv enabled | |

### AI / agent

| Var | Layer | Required | Notes |
|---|---|---|---|
| `AGENT_PROVIDER` | BE | Optional | `opencode` (default) \| `openai`. Selects which of the two provider pools below is active. |
| `AGENT_MODEL` | BE | Optional | Model name; must exist on the *active* provider. |
| `OPENCODE_BASE_URL` / `OPENCODE_API_KEY` | BE | Required if provider = opencode | Defaults to `https://opencode.ai/zen/v1`. |
| `OPENAI_BASE_URL` / `OPENAI_API_KEY` | BE | Required if provider = openai | Defaults to `https://api.openai.com/v1`. |
| `MCP_URL` | FE | Optional | Public MCP server URL surfaced to the client. **Currently MISSING on Vercel — see Known gaps.** |

### Email

| Var | Layer | Required | Notes |
|---|---|---|---|
| `EMAIL_PROVIDER` | BE | Optional | `resend` \| `nodemailer` \| unset (no-op `EmptyProvider`). |
| `RESEND_API_KEY` | BE | Required if provider = resend | |
| `EMAIL_FROM_ADDRESS` / `EMAIL_FROM_NAME` | BE | Required for any outbound email | Sync-send path no-ops and logs if either is missing. |

### Storage / uploads

| Var | Layer | Required | Notes |
|---|---|---|---|
| `STORAGE_PROVIDER` | BE | Required | `local` \| `cloudflare`. |
| `UPLOAD_DIRECTORY` / `NEXT_PUBLIC_UPLOAD_DIRECTORY` / `NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY` | BE + FE | Required if `local` | |
| `CLOUDFLARE_ACCOUNT_ID` / `CLOUDFLARE_ACCESS_KEY` / `CLOUDFLARE_SECRET_ACCESS_KEY` / `CLOUDFLARE_BUCKETNAME` / `CLOUDFLARE_BUCKET_URL` / `CLOUDFLARE_REGION` | BE + FE | Required if `cloudflare` | `CLOUDFLARE_BUCKET_URL` also read directly by FE layout. |

### Misc / optional

| Var | Layer | Required | Notes |
|---|---|---|---|
| `NEXT_PUBLIC_FACEBOOK_PIXEL` | FE | Optional | Marketing pixel. |
| `TELEGRAM_BOT_NAME` | FE | Optional | |
| `NEXT_PUBLIC_DISCORD_SUPPORT` | FE | Optional | Support-server link. |
| `NEXT_PUBLIC_POLOTNO` | FE | Optional | Design-editor integration key. |
| `API_LIMIT` | BE | Optional | Rate-limit knob. |
| `NX_ADD_PLUGINS` | BE | Optional | Build-time Nx flag, unrelated to runtime. |
| `POSTIZ_GENERIC_OAUTH` / `POSTIZ_OAUTH_*` | FE + BE | Optional | Generic OIDC (e.g. Authentik) login provider. |
| `DUB_TOKEN` / `SHORT_IO_SECRET_KEY` / `KUTT_API_KEY` / `LINK_DRIP_API_KEY` (+ endpoint/domain pairs) | BE | Optional | BYO short-link provider credentials. |
| `NEXT_PUBLIC_SENTRY_DSN` / `SENTRY_SPOTLIGHT` | FE + BE | Optional | Error monitoring. |

---

## Billing switch

`STRIPE_PUBLISHABLE_KEY` is the master on/off switch for paid mode, read in two places:

1. **`apps/backend/src/services/auth/permissions/permissions.service.ts:27`** —
   `getPackageOptions()`: if the subscription is null AND `STRIPE_PUBLISHABLE_KEY` is
   unset, the org's nominal tier resolves to `PRO` (not `FREE`).
2. **Same file, `check()` (~line 52)** — if `STRIPE_PUBLISHABLE_KEY` is unset, the
   method skips all tier-limit logic entirely and grants **every requested
   permission unconditionally** — channel caps, post-per-month caps, webhook caps,
   team-member gating, all bypassed. This is actually stronger than any paid tier
   (including `ULTIMATE`): it's "no limits," not "`ULTIMATE`'s limits."

Net effect: **deploying without `STRIPE_PUBLISHABLE_KEY` set silently puts every
organization in this instance into unlimited self-host mode.** There is no partial
state — it's binary per-deploy, not per-org.

- [ ] Confirm `STRIPE_PUBLISHABLE_KEY` + `STRIPE_SECRET_KEY` + `STRIPE_SIGNING_KEY` are
      all set on Railway before announcing paid plans publicly.
- [ ] Vault status (item "Stripe — CuantoSocials", checked 2026-08-06): live publishable
      key + full TEST pair present; **live secret key and live signing secret MISSING** —
      reveal/create the live secret key in the Stripe dashboard and store it in vault,
      then create the live webhook endpoint (`https://api.socials.cuantolabs.com/stripe`)
      via API to obtain the signing secret. Frontend env var is `STRIPE_PUBLISHABLE_KEY`
      on Vercel (no `NEXT_PUBLIC_` prefix — read server-side in `(app)/layout.tsx`).
- [ ] Confirm the matching `NEXT_PUBLIC_STRIPE_*`/publishable key is set on Vercel if
      the frontend renders Stripe Elements directly (check `apps/frontend` for a
      `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` usage before flipping this on — not
      enumerated above, verify at flip time).
- [ ] After setting keys, do one end-to-end test subscription + webhook round-trip in
      Stripe test mode before going live with real cards.
- [ ] `FREE_GRANT_MONTHS` (currently `3`) auto-grants new orgs `STANDARD` tier free for
      that window (`free.tier.ts`) — confirm this is the intended funnel before charging
      users who signed up expecting a permanent free tier (the raw `FREE` tier in
      `pricing.ts` is all-zeros / unusable as a product on its own).

---

## Known gaps

- [ ] **`STRIPE_SIGNING_KEY` missing on Railway.** Stripe webhook signature
      verification (`stripe.controller.ts`) will throw on every event — subscription
      state (upgrades, cancellations, payment failures) will not sync from Stripe.
      Set before enabling billing.
- [ ] **`X_API_KEY` / `X_API_SECRET` missing on Railway** while `x` is present in
      `ENABLED_INTEGRATIONS`. X (Twitter) connect/post/refresh will fail for any user
      attempting to link that channel. Either set the credentials or drop `x` from
      `ENABLED_INTEGRATIONS` until they're available.
- [ ] **`MCP_URL` missing on Vercel.** MCP server URL doesn't surface to the frontend;
      MCP-based agent integrations are effectively undiscoverable/unusable from the UI
      until set.
- [ ] **All stored `VERCEL_*` vault tokens found 403-dead (2026-07-30).** Rotate Vercel
      and Railway deploy tokens before the next deploy — do not assume the vault copies
      are still valid.
- [ ] Terms/privacy pages are placeholder templates (see Legal caveat) — must be
      replaced before charging.
- [ ] `Credits` ledger only meters `'ai_images'` — AI video generation (Veo 3) is a flat
      bundle per tier, not metered; real usage cost risk at scale (see
      `docs/MONETIZATION.md` §1, §4 M-3).
- [ ] Public REST API access is a boolean flag (`public_api`), not usage-metered —
      no rate/volume enforcement per plan beyond the flag itself.

---

## Deploy targets

| Target | Details |
|---|---|
| Frontend | Vercel project `prj_CYH0IyIX346Xey72QQIl8eUl0tSn`, prod domain `socials.cuantolabs.com`. Framework `nextjs`, build `pnpm run build:frontend`, output `apps/frontend/.next` (`vercel.json`). `/api/*` rewrites to `https://api.socials.cuantolabs.com/*`. |
| Backend | Railway project `428ac2f8`, service `b928eea3`. Nixpacks build: `pnpm install && pnpm run build:backend && pnpm run build:orchestrator && pnpm run build:workflows`. Start: `bash start.sh` (runs backend + orchestrator as two processes, or one if `RUN_ORCHESTRATOR_IN_PROCESS=true`). `preDeployCommand: pnpm run prisma-db-push` runs on every deploy — schema changes go live automatically on deploy, no separate migration gate. Compute pinned to `us-east-1` (co-located with Neon) via `railway.toml` multi-region config. |
| Database | Neon Postgres, `aws-us-east-1`, via `DATABASE_URL`. |
| Remote | Push to the `cuantolabs` remote (`github.com/Cuanto-Labs/cuanto-socials`) — **never** `origin` (upstream `gitroomhq/postiz-app`). |
| Branch model | `dev` → `staging` → `main`. `main` = production, auto-deploys both Vercel + Railway. Never commit directly to `main`. |

Go-live steps:
- [ ] Rotate Vercel + Railway deploy tokens (see Known gaps) and re-verify CI/CD can
      still deploy before relying on either.
- [ ] Confirm `main` branch protection / required checks before opening it to
      auto-deploy from merges.
- [ ] Verify Railway `preDeployCommand` (`prisma-db-push`) behavior is acceptable for
      production — it pushes schema directly, no migration history/rollback. Consider
      switching to `prisma migrate deploy` before scaling the team past solo-founder.
- [ ] Confirm DNS/TLS for `socials.cuantolabs.com` and `api.socials.cuantolabs.com`
      are both live and match `vercel.json` rewrite target.

---

## B2B notes

Enterprise/agency surface already shipped in this codebase:

- **Public REST API** (`components/public-api`, developer settings) — boolean
  `public_api` flag per tier, not usage-metered.
- **OAuth provider** — `OAuthApp` / `OAuthAuthorization` Prisma models let third
  parties build integrations on top of this instance (build-your-own-app flow).
- **MCP server** (`libraries/nestjs-libraries/src/chat/start.mcp.ts`) — lets AI
  agents drive scheduling directly; currently self-identifies as `'Postiz MCP'` and
  is unpositioned/unmarketed. Requires `MCP_URL` set on Vercel to surface (Known gaps).
- **Webhooks** — `Webhooks` model, metered per tier (2 / 10 / 30 / 10000 across
  STANDARD / TEAM / PRO / ULTIMATE).
- **Multi-org workspaces** — users can belong to multiple orgs (`UserOrganization`),
  each with its own subscription/tier/channels.
- **`Customer` model** — groups channels under a named client within one org; this is
  the agency primitive (one workspace managing multiple end-clients' channels).

None of the above (API metering, white-label branding, per-seat pricing) has a
dedicated B2B/agency price tier yet — see `docs/MONETIZATION.md` §4 (M-1, M-5) for
the proposed API SKU and agency/white-label tier if pursuing this.

---

## Legal caveat

- **Terms of Service and Privacy Policy pages in this repo are unmodified/template
  content.** They must be reviewed and finalized by an attorney before charging any
  customer or processing personal data at scale. Do not treat their current text as
  binding legal coverage.
- **License: AGPL-3.0** (`LICENSE`). Running this as a network service triggers
  AGPL §13 — any user interacting with it over the network must be offered the
  complete corresponding source of the running (modified) version. Practically:
  - A public source repo + a "source" link reachable from the app satisfies this;
    charging for the hosted service is compatible with AGPL (this is the
    Postiz/Gitroom upstream model itself).
  - Proprietary/closed modules (e.g. white-label add-ons, metering logic) cannot be
    shipped as part of this same running network service without either publishing
    their source too, or splitting them into a genuinely separate, arm's-length
    service — get this specific architecture reviewed by an attorney before building
    on that assumption.
  - Trademark is separate from copyright — AGPL grants no rights to the "Postiz"
    name/marks; remaining upstream branding should be stripped for a commercial
    launch (see `docs/MONETIZATION.md` §6.4).
  - See `docs/MONETIZATION.md` §6 for the fuller legal/monetization analysis this
    checklist summarizes.

---

## Sources

Every claim above is grounded in a direct code read at commit time of this doc:
`pricing.ts`, `permissions.service.ts`, `free.tier.ts`, `ai.provider.ts`,
`stripe.service.ts`, `stripe.controller.ts`, `x.provider.ts`,
`integration.manager.ts`, `email.service.ts`, `resend.provider.ts`, `proxy.ts`,
`docker-compose.yaml`, `railway.toml`, `vercel.json`, `start.sh`, `LICENSE`, plus
run-state facts from `.claude/autopilot/STATE.md` and `docs/MONETIZATION.md`.
