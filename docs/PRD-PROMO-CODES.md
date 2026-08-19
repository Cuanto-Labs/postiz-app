# PRD — DB-Driven Promo Codes (tier grants + redemption)

**Status:** proposed · **Owner:** Eliran Yihye · **Date:** 2026-08-19
**Repo:** `Cuanto-Labs/cuanto-socials` · **Deploys:** frontend Vercel, backend `pz-app` on deb

---

## 1. Problem

An operator has no way to grant a customer a plan. Today the only paths to a paid tier are Stripe checkout, or `POST /billing/add-subscription`, which reads the org from the caller's own session (`@GetOrgFromRequest`) and therefore can only upgrade the superadmin's own org.

The upstream escape hatch is worse: `/billing/lifetime` renders a code box that posts to `POST /billing/lifetime`, **a route that does not exist in this build** — it 404s and always toasts "invalid code". Its service (`StripeService.lifetimeDeal`, `stripe.service.ts:1297`) expects a code produced by `AuthService.fixedEncryption`, an AES blob, so a human-typed code like `RONRON` can never validate. It also hard-rejects any org holding a non-lifetime subscription — which includes every trial user.

Concrete trigger: **Ron Sapir** (`ronsa007@gmail.com`, org *Workaholix*, STANDARD trial, LinkedIn connected, 0 posts) should be able to type `RONRON` and land on PRO. Today that is impossible without direct DB access.

## 2. Goals

- Codes live entirely in the DB. Tier, lifetime flag, and usage limits are **columns**, configured from the admin panel — nothing hard-coded, no deploy to mint or change a code.
- An **already-registered** user can redeem a code and be upgraded in-product.
- A code redeemed at **signup** applies its tier to the new org.
- Reuse the existing `InviteCode` table, admin UI, and subscription service. No new code-generation scheme, no `fixedEncryption`, no second table.
- Redemption is visibly celebratory — confetti plus an animated tier change.

### Non-goals

- Stripe coupons/discounts (`/billing/apply-coupon` already covers that).
- Percentage-off or trial-extension codes. Tier grants only, v1.
- Self-serve code creation by non-superadmins.
- Reviving `StripeService.lifetimeDeal` — this replaces its purpose.

## 3. What already exists (reuse, do not rebuild)

| Piece | Location | Reuse as |
|---|---|---|
| `InviteCode` model — `code` unique, `label`, `active`, `expiresAt`, `timesUsed` | `schema.prisma:139` | the promo-code table |
| `InviteCodesRepository` — `findUsable`, `markUsed`, `create/update/delete`, `upsertSeed` | `.../invite-codes/invite-codes.repository.ts` | unchanged lookup layer |
| `InviteCodesService.isAcceptable()` | `.../invite-codes/invite-codes.service.ts` | signup validation |
| Admin CRUD API `/admin/invite-codes` (superadmin-gated) | `admin.controller.ts:120-168` | code management API |
| Admin UI table + create form | `components/admin/admin-codes.component.tsx` | code management UI |
| Redeem box page | `app/(app)/(site)/billing/lifetime/page.tsx` + `components/billing/lifetime.deal.tsx` | user-facing redeem screen |
| `SubscriptionService.createOrUpdateSubscription()` | `.../subscriptions/subscription.service.ts:178` | applies the grant |
| Tier definitions incl. channel counts | `.../subscriptions/pricing.ts` | source of `totalChannels` |
| Live codes `CREATORS`, `AGENCIES`, `LAUNCH` | DB | must keep working untouched |

## 4. Schema change

Three nullable/defaulted columns on `InviteCode` — additive, one migration:

```prisma
model InviteCode {
  // ... existing fields ...
  tier       SubscriptionTier?  // null = attribution-only code (today's behavior)
  isLifetime Boolean  @default(false)
  maxUses    Int?               // null = unlimited
}
```

`SubscriptionTier` is the existing enum: `STANDARD | PRO | TEAM | ULTIMATE` (`schema.prisma:926`). Note it has **no `FREE` member** even though `pricing.ts` defines a FREE entry — do not add one in this change.

Backfill: none. Existing rows get `tier = null` and behave exactly as today.

`findUsable` gains a `maxUses` check: reject when `maxUses != null && timesUsed >= maxUses`.

## 5. Behavior

### 5.1 Redeem as a logged-in user (the new path)

`POST /billing/redeem { code }` on `billing.controller.ts`:

1. `findUsable(code)` → `{ success: false, reason: 'invalid' }` when missing, inactive, expired, or over `maxUses`.
2. `tier == null` → `{ success: false, reason: 'not_upgradeable' }`. Attribution codes are not redeemable.
3. Org already on a **paid, non-trial** subscription (`paymentId != null`) → `{ success: false, reason: 'has_paid_subscription' }`. Do not silently clobber billing; operator handles those in Stripe.
4. Otherwise apply the grant:
   - `totalChannels = pricing[tier].channel`
   - `createOrUpdateSubscription(false, makeId(10), org.id, totalChannels, tier, 'MONTHLY', null, <code>, org.id)`
   - **Trial handling:** the existing trial row is upserted in place (`Subscription.organizationId` is `@unique`), and `organization.isTrailing` must be cleared so the trial banner and `/billing/is-trial-finished` stop firing.
5. `markUsed(id)` — increments `timesUsed`, which the admin table already renders.
6. Return `{ success: true, from: <previousTier>, to: <tier>, isLifetime }` so the UI can animate the transition.

**Implementation trap — the `code` argument is load-bearing.** In `createOrUpdateSubscription`, a falsy `code` makes it call `modifySubscription()` against Stripe first, which fails for a comped org with no Stripe customer. Passing the code short-circuits that. But the repository then writes `isLifetime: !!code` (`subscription.repository.ts:207,214`), hard-coupling "comped" to "lifetime". **Change that to accept an explicit `isLifetime` argument** so a non-lifetime comped tier is expressible; default it to the current behavior for existing callers.

### 5.2 Redeem at signup

`auth.controller.ts:59` already calls `isAcceptable(body.inviteCode)`. After org creation, if the code carries a tier, apply the same grant to the new org. One code system serves both entry points. `isAcceptable` already increments `timesUsed`, so the redeem path must not double-count — return the row from a single lookup and increment exactly once.

### 5.3 Admin management

Extend `AdminCodesComponent` create form and table with: **Tier** (select — None / STANDARD / TEAM / PRO / ULTIMATE), **Lifetime** (checkbox), **Max uses** (number, blank = unlimited). Extend the `POST`/`PUT` bodies in `admin.controller.ts` and the corresponding service/repository signatures to carry the three fields. Table gains Tier and `Uses / Max` columns.

Copy on the page needs updating — it currently states codes are for attribution only, which stops being true.

`RONRON` is then a row created in the panel: tier `PRO`, lifetime true, maxUses 1.

### 5.4 Redeem UI + animation

Repurpose `components/billing/lifetime.deal.tsx` (keep the `/billing/lifetime` URL so existing links survive; add a `/billing/redeem` alias):

- Point `claim()` at `/billing/redeem`.
- Success: `canvas-confetti` burst — **no animation library is currently installed** (no confetti/framer/lottie in `package.json`), so this adds one ~2kB dependency. Everything else uses Tailwind keyframes already in the theme.
- Tier badge animates `from` → `to` (scale + glow), channel count counts up to the new `totalChannels`.
- `mutate('/user/self')` so the header, channel limit, and trial banner refresh without a reload. `fireEvents('lifetime_claimed')` stays for analytics.
- Failure: distinct toast per `reason` instead of today's single catch-all.

## 6. Acceptance criteria

1. Superadmin creates `RONRON` (PRO, lifetime, maxUses 1) in `/admin/codes` with no deploy.
2. Ron, logged in on a STANDARD trial, redeems `RONRON` → org is PRO, `totalChannels` 30, `isLifetime` true, `isTrailing` false, confetti fires, header updates without reload.
3. Second redemption of `RONRON` by anyone fails with `maxUses` exhausted; `timesUsed` reads 1 in the admin table.
4. `CREATORS` / `AGENCIES` / `LAUNCH` still pass signup validation and grant no tier.
5. A code with `tier = null` is rejected at `/billing/redeem` as `not_upgradeable`.
6. An org with a real Stripe subscription is rejected as `has_paid_subscription` and its billing is untouched.
7. A new signup using a tier-bearing code lands on that tier; `timesUsed` increments exactly once.

## 7. Risks

| Risk | Mitigation |
|---|---|
| `isLifetime: !!code` coupling silently grants lifetime on every comped upgrade | explicit `isLifetime` arg, covered by acceptance #2 and a non-lifetime case |
| Double-increment of `timesUsed` across `isAcceptable` + redeem | single lookup, single `markUsed`, acceptance #7 |
| Comped path touching Stripe for an org with no customer | pass `code` to skip `modifySubscription`; test on an org with `paymentId = null` |
| Code sharing — a leaked code drains grants | `maxUses` (default 1 in the admin form) + `expiresAt` + `active` toggle |
| Migration on the shared Neon DB used by Prisma and Mastra | additive columns only, no backfill, no table rewrite |

## 8. Out of scope / follow-ups

- Per-code channel override independent of `pricing.ts`.
- Redemption audit log (who redeemed which code, when) — `timesUsed` only counts.
- Expiring a granted tier after N months.

## 9. Ship notes

Bundle with two open fixes already diagnosed on this stack:

- `agent="postiz"` in `components/agents/agent.chat.tsx:54` — the rebrand renamed the CopilotKit agent key and broke AI chat.
- `DROP TABLE mastra_ai_spans` — at Postgres' 1600-column cap (1562 dropped slots), 0 rows, blocking every Mastra ALTER.

Deploy: `postiz-stack.sh deploy` (backend on deb) + Vercel auto-deploy on `main`. Branches: `dev` → `staging` → `main`.
