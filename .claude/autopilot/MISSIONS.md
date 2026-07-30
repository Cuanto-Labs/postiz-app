# MISSIONS — ordered backlog

## M0: Build the verify gate
status: DONE
goal: Root package.json script `verify` = prisma schema validate + frontend typecheck; green.
acceptance: `pnpm run verify` exits 0 from repo root; introducing a deliberate type error in apps/frontend makes it exit non-zero (then revert). If pre-existing frontend type errors exist, fix them or (if >20, unrelated) scope gate to a documented baseline script that still fails on NEW errors — record choice in AGENTS.md.
fails: 0
attempts: []

## M1: Unblock /join campaign pages for logged-out visitors
status: DONE
goal: Add `/join` to the logged-out pass-through allow-list in apps/frontend/src/proxy.ts (currently only /uploads/, /p/, /provider/, /icons/, /terms, /privacy at proxy.ts:46-55) so campaign landing pages render and the invite code survives. Also fix stale doc comment in apps/frontend/src/components/landing/campaigns.ts:5-9 (claims REGISTRATION_CODE env allow-list; codes now live in DB InviteCode model).
acceptance: proxy.ts allow-list includes /join; campaigns.ts comment describes DB invite codes; `pnpm run verify` green.
fails: 0
attempts: []

## M2: Root marketing landing page
status: DONE
goal: Public marketing page served to logged-out visitors at `/`: hero (AI-powered social publishing), feature grid grounded in real features (AI post generator w/ web research, Copilot chat, image gen incl. design editor, AI video gen w/ voiceover, multi-channel scheduling, calendar, analytics, team management, public API + MCP), channel logos row, CTA → /auth, shared public nav + footer (terms/privacy links). Authed `/` behavior unchanged (→ /launches). Dark theme, accents #10b981/#6366f1, reuse landing.page.tsx patterns. Follow repo CLAUDE.md frontend conventions (no npm UI libs, tailwind 3, check colors.scss).
acceptance: route renders marketing page for logged-out `/` (proxy.ts updated accordingly); authed redirect intact in code; `pnpm run verify` green.
fails: 0
attempts: []

## M3: Public /pricing page
status: TODO
goal: Public `/pricing` route rendering tier cards imported from libraries/nestjs-libraries/src/database/prisma/subscriptions/pricing.ts (import or shared re-export — zero hardcoded prices), monthly + yearly prices, per-tier limits (channels, posts/month, AI image + video credits, team members, API), free-trial note (3-month STANDARD grant), FAQ section (reuse/adapt components/billing/faq.component.tsx if usable), CTA → /auth. Linked from marketing nav.
acceptance: /pricing public (proxy allow-list), imports pricing.ts constants, nav link present; `pnpm run verify` green.
fails: 0
attempts: []

## M4: B2C/B2B segmentation on landing
status: TODO
goal: Landing gets two audience sections — "For creators" (B2C: AI content, scheduling, growth) and "For agencies & teams" (B2B: multi-org workspaces, roles/permissions, customer grouping on channels, team invites, public API + MCP for automation) — each linking to its /join campaign (/join/creators, /join/agencies). Ensure /join pages share the public nav/footer shell for consistency.
acceptance: both sections render with correct links; /join pages carry shared shell; `pnpm run verify` green.
fails: 0
attempts: []

## M5: SEO + brand polish on public surfaces
status: TODO
goal: Metadata exports (title/description/OpenGraph) for /, /pricing, /join/* ; robots.txt + sitemap covering public routes; favicon and any user-visible asset references switched off Postiz leftovers (public/postiz.svg, postiz-text.svg, postiz-fav.png) to Cuanto Socials branding; grep public pages for visible "Postiz" strings and remove.
acceptance: metadata present on all public routes; robots+sitemap exist; no user-visible "Postiz" on public pages (grep evidence); `pnpm run verify` green.
fails: 0
attempts: []

## M6: Go-live launch checklist
status: TODO
goal: Write docs/LAUNCH-CHECKLIST.md — env matrix per layer (Vercel frontend / Railway backend) with the known gaps and switches: STRIPE_PUBLISHABLE_KEY presence = billing master switch (absent ⇒ self-host free mode w/ ULTIMATE perms — permissions.service.ts:27), STRIPE_SIGNING_KEY missing on Railway (webhooks will fail), X_API_KEY/X_API_SECRET/X_URL missing while ENABLED_INTEGRATIONS includes x, MCP_URL missing on Vercel, DISABLE_REGISTRATION, FREE_GRANT_MONTHS, AGENT_PROVIDER pool, ENABLED_INTEGRATIONS filter. Plus: deploy targets (Vercel prj_CYH0IyIX346Xey72QQIl8eUl0tSn, Railway backend svc b928eea3), B2B enterprise API + OAuth apps notes, legal-template caveat (terms/privacy are templates, need attorney review).
acceptance: docs/LAUNCH-CHECKLIST.md exists with sections {Env matrix, Billing switch, Known gaps, Deploy targets, B2B notes, Legal caveat}; no secret VALUES in the doc.
fails: 0
attempts: []

## M7: Visual QA screenshots
status: TODO

goal: Run frontend dev server (frontend-only if backend not needed for public pages; check for already-running server on the port first per fleet rule), capture desktop + mobile screenshots of / (landing) and /pricing, save under .claude/autopilot/screens/. Delegate to visual-qa/e2e style subagent; bytes stay out of orchestrator thread.
acceptance: ≥4 screenshot files exist (landing+pricing × desktop+mobile) showing rendered marketing content (not an /auth redirect); paths logged in STATE.md.
fails: 0
attempts: []

## M8: Promote + deploy to production (Vercel + Railway)
status: TODO
goal: Runs LAST, only when M0-M7 all DONE/BLOCKED. Merge autopilot/saas-launch → dev → staging → main (merges, never force). Push dev, staging, main to `cuantolabs` remote ONLY (github.com/Cuanto-Labs/cuanto-socials; NEVER origin = upstream postiz). Then verify deploys picked up: Vercel project cuanto-socials (prj_CYH0IyIX346Xey72QQIl8eUl0tSn) shows new production deployment READY serving the marketing landing (curl https://socials.cuantolabs.com/ logged-out → 200 marketing page, /join/creators → 200); Railway backend service (project 428ac2f8, service b928eea3) redeployed successfully. Tokens: RAILWAY_TOKEN fresh from vault (local ~/.secrets copy is dead), VERCEL_WRITE_TOKEN from vault (NOT VERCEL_TOKEN). Commit author must be eliran@cuantotec.com (already set).
acceptance: git log shows main == staging == dev tip containing all mission commits, pushed to cuantolabs remote; curl prod / returns marketing page HTML (200, no /auth redirect) and /join/creators 200; Vercel deployment state READY on latest commit SHA; Railway deployment SUCCESS on latest commit SHA.
fails: 0
attempts: []
