# Cuanto Socials — Monetization & SaaS Launch Strategy

Research date: 2026-08-05. Competitor prices scraped live (Firecrawl/Scrapling) from vendor
pricing pages. Feature inventory read from this repo at `autopilot/saas-launch`.

---

## 0. The headline problem

`libraries/nestjs-libraries/src/database/prisma/subscriptions/pricing.ts` ships
**$29 / $39 / $49 / $99** — byte-identical to postiz.com's public cloud pricing
(verified live: `$29/mo`, `$39/mo`, `$49/mo`, `$99/mo`).

Shipping a Postiz fork at Postiz prices with Postiz features means competing head-on
with the upstream project, which owns the brand, the GitHub stars, the docs domain, and
the Google results. That is the weakest possible position. Everything below is about
moving off that square.

---

## 1. Asset inventory — what this codebase can already charge for

### Live and shipping
| Asset | Where | Monetization status |
|---|---|---|
| 35 social providers | `libraries/.../integrations/social/*.provider.ts` | Gated by `channel` count per tier |
| Scheduling + calendar + sets | `components/launches`, `sets` | Bundled |
| AI post generator, Copilot chat | `libraries/.../chat`, `copilot.controller.ts` | Boolean `ai` flag |
| AI image gen | `Credits` model, `type: 'ai_images'` | **Already metered** — credit ledger exists |
| AI video gen (Veo 3 + image-slides) | `components/videos/providers/veo3.provider.tsx` | Flat bundle 3/10/30/60 per tier — **COGS risk** |
| Public REST API | `components/public-api` | Boolean flag only, **not metered** |
| MCP server | `libraries/nestjs-libraries/src/chat/start.mcp.ts` | **Free, unpositioned** |
| OAuth provider (3rd-party apps) | `OAuthApp` / `OAuthAuthorization` models | Unmonetized |
| Webhooks | `Webhooks` model | Metered 2/10/30/10000 |
| Autopost (RSS → AI → publish) | `autopost.service.ts` | Boolean, TEAM+ |
| Plugs (auto-engagement) | `@Plug()` on x, bluesky, linkedin.page, threads | Bundled, only 4/35 providers |
| Team members + roles | `UserOrganization` | Boolean `team_members` |
| Customers (client grouping on channels) | `Customer` model | Bundled — this is the agency primitive |
| Chrome extension | `apps/extension` | Distribution asset, unmonetized |
| Signatures, third-party media import, analytics | various | Bundled |
| Lifetime deal path | `Subscription.isLifetime`, `billing/lifetime.deal.tsx` | **Coded, dormant** |
| Stripe auto-provisioning of products/prices | `services/stripe.service.ts` | Working |

### Coded but dormant — free revenue surfaces sitting in the schema
| Asset | Models | What it is |
|---|---|---|
| **Influencer marketplace** | `Orders`, `OrderItems`, `Messages`, `MessagesGroup`, `PayoutProblems`, `captureId` | Buyer/seller ordering of sponsored posts with escrow + payouts. Gitroom legacy. Take-rate business, fully modelled. |
| **Agency directory** | `SocialMediaAgency`, `SocialMediaAgencyNiche`, `approved` flag | Curated, admin-approved agency listings by niche. Listing-fee / lead-gen business. |
| **Self-host / open-core** | AGPL-3.0 `LICENSE`, `IS_GENERAL` flag, docker-compose, Railway/Vercel configs | Managed-hosting and support revenue. |

### Planned, high-differentiation
`FUTURE-FEATURES.md` — AI auto-comment/auto-reply with anti-slop validator, human-in-loop,
rate-paced sending. Write path already proven live against LinkedIn (2026-06-28). **This is
the strongest genuine differentiator in the repo.** Nobody in the comparison set sells
AI-drafted, brand-voice, review-gated reply automation as a product.

---

## 2. Competitor price map (live, 2026-08-05)

### Classic SMM suites
| Product | Entry | Mid | Top | Pricing axis |
|---|---|---|---|---|
| Buffer | $5/ch/mo | $10/ch/mo (Team) | — | **Per channel** |
| Later | $18.75/mo | $37.50/mo | $82.50/mo | Social sets + seats |
| Publer | — (JS-rendered) | Professional / Business | Enterprise | **Per social account + per member**, 10th free each |
| Vista Social | $64/mo ($758/yr) | $120/mo ($1,430/yr) | $304/mo ($3,638/yr) | Per profile + **paid add-ons** |
| Hootsuite | $99/user/mo | $199/user/mo | $399/user/mo | **Per seat** |
| Sprout Social | $79–$199/seat/mo | $299/seat/mo | $399/seat/mo | **Per seat** |
| Ocoya | $15 | $39 / $79 | $159 | Flat tiers |
| Hypefury | from $6/mo | — | — | Flat |
| Blotato | $29/mo | $97/mo | $499/mo | AI credits |
| **Postiz cloud (upstream)** | **$29** | **$39 / $49** | **$99** | Flat tiers |
| **Cuanto Socials (today)** | **$29** | **$39 / $49** | **$99** | Identical |

### API-first / agent-first (the fast-growing, high-ARPU segment)
| Product | Model | Numbers |
|---|---|---|
| **Ayrshare** | Per-profile, volume-tiered | $149 / $299 / $599+ per mo; profiles $8.99 → $1.99 at scale; effective $12.28/profile at 100 |
| **Late (getlate.dev)** | Graduated per-account **+ per-request** | First 2 accounts free; $6/acct (3–10), $3 (11–100), $1 (101+). Reads $0.005/req, posts $0.015/req, **posts-with-URL $0.20/req**. Plus SMS/voice/ads add-ons. |
| **Upload-Post** | Tiered + per-profile overage | $0 / $16 / $33 / $118 / $350 per mo; extra profiles **+$1/mo** each |

**Read this table twice.** Ayrshare's *entry* plan is $149/mo — 5× your top-of-funnel
price — for strictly less product than you have (no UI, no calendar, no AI video). The
API/agent segment tolerates 5–20× the price per unit of value that the creator UI segment
does. You are currently pricing your API at **$0** as a checkbox on a $29 plan.

### Add-on precedent (nobody bundles everything — you shouldn't either)
- Later: extra social set **$11.25/mo**, extra user **$3.75/mo**, **100 AI credits $3.75/mo**
- Vista Social: employee advocacy **from $199/mo (25 seats)**, listening **$75/mo**,
  white-label setup, review management, link-in-bio — all à la carte
- Late: phone numbers, SMS ($0.008/msg), managed ads — metered add-ons on top of base

---

## 3. Gaps — what competitors charge for that this repo does not have

| Gap | Who monetizes it | Build cost |
|---|---|---|
| **Social inbox** (inbound comments/DMs) | Sprout, Hootsuite, Vista core value prop | Medium — `FUTURE-FEATURES.md` Phase 1 covers the hard part |
| **Link-in-bio page** | Later, Publer (unbranded), Vista Page | **Low** — you already have public routes, media, auth |
| **Social listening** | Vista $75/mo, Sprout core | High |
| **Review management** | Vista | High |
| **Employee advocacy** | Vista $199/mo/25 | Medium |
| **Approval workflows** | Later, Publer | Low–medium — `UserOrganization` roles exist; `Comments` model is internal draft notes only, not inbound social |
| **White-label reports/dashboard** | Vista (paid add-on) | **Low** — no `NEXT_PUBLIC_APP_NAME` exists yet; VISION.md lists it as a v1 non-goal |
| **Owned link shortener + click analytics** | Buffer, Later | Low — `short-linking/` exists but delegates to dub/kutt/short.io (BYO keys, no margin) |
| **Boosting / paid ads** | Publer, Vista, Late | High |

---

## 4. Monetization moves, ranked by (revenue × speed) ÷ effort

### Tier 1 — do these first

**M-1. Launch an API/MCP product line, priced like Ayrshare, not like Buffer.**
The single biggest arbitrage in this table. You already have the REST API, an OAuth
provider, webhooks, and an MCP server. Package them as a separate SKU:

| SKU | Price | Includes |
|---|---|---|
| API Starter | $99/mo | 10 profiles, 10k API calls, 5 webhooks, MCP access |
| API Growth | $299/mo | 50 profiles, 100k calls, unlimited webhooks, OAuth app |
| API Scale | $799/mo | 250 profiles, 1M calls, SLA, dedicated support |
| Overage | $2/profile/mo, $0.001/call | Graduated like Late |

Meter it with the `Credits` ledger (extend `type` beyond `'ai_images'`) and enforce in the
public-api guard. Ayrshare validates $149 as a floor; you can undercut at $99 and still be
3.4× your current top-of-funnel.

**M-2. Position as the MCP-native / agent-native scheduler.**
`start.mcp.ts` exists and is currently labelled `'Postiz MCP'`. Rename, document, and put
it on the landing page. In 2026 "your AI agent can post for you" is a category, and none of
Buffer/Later/Hootsuite/Sprout ship an MCP server. Late and Ayrshare sell APIs but not
agent-native positioning. This is a free wedge you already own — it costs a rename, a docs
page, and a landing section. Pair with the existing `postiz-agent` CLI concept.

**M-3. Meter AI video, or it eats the margin.**
Veo 3 is expensive per generation. Today ULTIMATE bundles 60 videos into $99/mo. Move video
(and heavy image gen) onto the `Credits` ledger and sell packs — Later's precedent is
$3.75 per 100 AI credits; Blotato sells $29→$499 tiers on AI credits alone. Suggested:
1,000 credits $19, 5,000 credits $79, 20,000 credits $249. Keep a small bundled grant per
tier so the feature still demos.

**M-4. Split channels from features (per-channel add-on).**
Every serious competitor charges per channel/profile/seat; you charge flat and cap hard at
5/10/30/100. Add `+$4/channel/mo` beyond tier cap (Upload-Post charges +$1, Later $11.25,
Vista per-profile). This converts your hardest churn moment ("I hit the cap") into revenue
instead of a downgrade decision. `Subscription.totalChannels` already exists.

**M-5. Agency / white-label tier — the highest-ARPU segment you can serve today.**
`Customer` model already groups channels by client. Add `NEXT_PUBLIC_APP_NAME` + logo +
custom domain + branded reports, and sell **$249–$399/mo**. Vista charges for white-label
setup as an add-on; Hootsuite/Sprout charge $399/seat. Agencies are the buyer that
tolerates this price and the one your `/join/agencies` campaign already targets.

### Tier 2 — high value, needs build

**M-6. Ship the Engagement / auto-reply product as a paid add-on ($29–$79/mo/account).**
`FUTURE-FEATURES.md` Phase 1. Genuine differentiation, proven write path, and it's the one
thing on this list a competitor cannot copy by changing a price. Sell per connected account
so it scales with agencies.

**M-7. Link-in-bio + owned short links.** Low build, high attach rate, and click analytics
gives you a data moat. Replace/augment the BYO dub/kutt delegation with a first-party
shortener so the traffic (and the upsell) is yours.

**M-8. Activate the marketplace (`Orders`/`OrderItems`/`PayoutProblems`).**
Take-rate revenue (10–20%) on sponsored-post orders between buyers and channel owners. Fully
modelled already — needs Stripe Connect wiring and a UI. Only turn this on once you have
supply-side density; a dead marketplace is worse than none.

**M-9. Activate the agency directory (`SocialMediaAgency`, `approved`).**
Charge for a featured listing ($49–$99/mo) once you have inbound traffic on the marketing
site. Also doubles as SEO surface area.

### Tier 3 — opportunistic

**M-10. Lifetime deal launch.** `isLifetime` + `lifetime.deal.tsx` are already coded. An
AppSumo-style LTD ($59–$149) is the standard cold-start move for this category — cash now,
users now, reviews now. Cap the seats and cap the channel allowance, or you buy permanent COGS.

**M-11. Open-core / managed self-host.** AGPL forces you to publish modifications anyway
(see §6) — so sell what AGPL can't copy: managed hosting, migration, SLA support,
priority provider onboarding. $500–$2,000/mo enterprise support contracts.

**M-12. Affiliate + reseller program.** 20–30% recurring. Cheapest CAC in this category;
Publer/Vista/Blotato all run one.

**M-13. Extension as a funnel.** The Chrome extension is a distribution asset — free tier
that requires an account, harvesting the LinkedIn session data the Engagement product needs.

---

## 5. Concrete proposed pricing

Two ladders, because you serve two different buyers with the same backend.

### Ladder A — humans (UI)
| Tier | Price/mo | Channels | Key limits |
|---|---|---|---|
| Free | $0 | 2 | 30 posts/mo, no AI, watermark on link-in-bio |
| Creator | $19 | 5 | 400 posts, 500 AI credits, 2 webhooks |
| Pro | $49 | 15 | Unlimited posts, 2,000 credits, autopost, plugs, API read |
| Team | $99 | 30 | + team seats, approvals, customers, 10k credits |
| Agency (white-label) | $299 | 100 | + branding, custom domain, branded reports, priority support |

Add-ons: extra channel **+$4/mo** · credit packs **$19 / $79 / $249** · Engagement/auto-reply
**+$29/account/mo** · listening (later) · advocacy (later).

Note: Free tier at $0 with 2 channels mirrors Late's "first 2 accounts free" and gives you
a funnel the current `FREE` tier (all zeros — literally unusable) does not.

### Ladder B — machines (API / MCP)
As in **M-1**. Same infrastructure, 3–8× the ARPU, sold to a buyer who never opens the UI.

### Why this beats today's $29/$39/$49/$99
- Stops being a price-identical clone of upstream Postiz
- Adds a real free tier (funnel) and a real $299 tier (ARPU)
- Converts the channel cap from churn trigger into expansion revenue
- Puts AI COGS behind a meter instead of a flat bundle
- Opens a second revenue line (API/MCP) at 3–8× the price with zero new infra

---

## 6. Publishing as SaaS — the blocking checklist

### Legal — read this before you charge anyone
**The repo is AGPL-3.0** (`LICENSE`). Running it as a network service triggers §13: users
interacting with it over a network must be offered the **complete corresponding source of
your modified version**. Practical consequences:
1. You must publish your fork's source (a public repo + a "source" link in the app footer
   satisfies this). This is compatible with charging for the hosted service — that is
   exactly the Postiz/Gitroom model.
2. You **cannot** close-source the white-label, Engagement, or API-metering work while
   serving it over the network from this codebase.
3. If you want proprietary modules, they must be genuinely separate services (own process,
   own repo, arm's-length API) — get this reviewed by an attorney before building on the
   assumption. Alternatively negotiate a commercial license with the upstream copyright
   holder.
4. Strip remaining upstream branding (M5 in `MISSIONS.md`) — trademark is separate from
   copyright, and AGPL grants you no rights to the Postiz name or marks.

### Product gaps before charging
- [ ] `FREE` tier in `pricing.ts` is all zeros — no usable free product, no funnel
- [ ] Public API is a boolean, not metered — cannot sell Ladder B until it is
- [ ] `Credits` ledger only knows `'ai_images'` — extend to video, API calls, agent tokens
- [ ] No `NEXT_PUBLIC_APP_NAME` — blocks the white-label tier (currently a VISION.md non-goal; promote it)
- [ ] MCP server still self-identifies as `'Postiz MCP'` (`start.mcp.ts:40`)

### Infra gaps (from `MISSIONS.md` M6, already known)
- [ ] `STRIPE_SIGNING_KEY` missing on Railway — **webhooks fail, subscriptions won't sync**
- [ ] `STRIPE_PUBLISHABLE_KEY` presence is the billing master switch (absent ⇒ everyone gets ULTIMATE free — `permissions.service.ts:27`)
- [ ] `X_API_KEY` / `X_API_SECRET` missing while `x` is in `ENABLED_INTEGRATIONS`
- [ ] `MCP_URL` missing on Vercel
- [ ] Terms/privacy are templates — need attorney review before taking payment

### Remaining launch missions
M3 (public `/pricing`), M4 (B2C/B2B segmentation), M5 (SEO + de-Postiz branding),
M6 (launch checklist), M7 (visual QA), M8 (promote + deploy) — all still TODO.

---

## 7. Recommended sequence

1. **M8 unblock + M3/M5** — get a public, branded, priced site live (already in flight)
2. **Fix `FREE` tier + add per-channel add-on** — one file, `pricing.ts`; immediate funnel + expansion revenue
3. **Meter the credit ledger** (video + API calls) — protects margin before volume arrives
4. **Ship Ladder B (API/MCP SKU)** — biggest revenue-per-effort item on this page
5. **White-label / agency tier** — needs `NEXT_PUBLIC_APP_NAME`; highest ARPU
6. **Engagement add-on** (`FUTURE-FEATURES.md` Phase 1) — the durable differentiator
7. **LTD launch or marketplace/directory activation** — cold-start / long-tail
