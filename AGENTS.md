<!-- Canonical instruction file. CLAUDE.md is a one-line `@AGENTS.md` pointer — edit this file only. -->

# Cuanto Socials (Postiz fork)

This project is Postiz, a tool to schedule social media and chat posts to 28+ channels.
You can add posts to the calendar, they will be added into a workflow and posted at the right time.
Feature areas: scheduled posts, calendar view, analytics, team management, media library.

Monorepo with a root-only package.json of dependencies. Made with PNPM — use only pnpm, no other dependency manager.

- `apps/backend` — API code (NestJS)
- `apps/orchestrator` — Temporal background jobs (NestJS); all workflows and activities
- `apps/frontend` — frontend (**Next.js App Router**, `apps/frontend/src/app`)
- `libraries/` — services shared between backend, orchestrator, and frontend

## Dev

- `pnpm run --filter ./apps/extension --filter ./apps/orchestrator --filter ./apps/backend --filter ./apps/frontend --parallel dev` — dev server (port 3000)
- `pnpm -r --workspace-concurrency=1 --filter ./apps/frontend --filter ./apps/backend --filter ./apps/orchestrator run build && pnpm run build:workflows` — production build
- `jest --coverage --detectOpenHandles --reporters=default --reporters=jest-junit` — tests (see Gotchas below: `pnpm test` is currently broken)
- `pnpm typecheck` — type check (tsgo --noEmit for speed)

## Environment (local dev defaults)

- `DATABASE_URL` — `postgresql://postiz-user:postiz-password@localhost:5432/postiz-db-local`
- `REDIS_URL` — `redis://localhost:6379`
- `JWT_SECRET` — random string for your JWT secret, make it long
- `FRONTEND_URL` — `http://localhost:4200`
- `NEXT_PUBLIC_BACKEND_URL` — `http://localhost:3000`
- `BACKEND_INTERNAL_URL` — `http://localhost:3000`

## Conventions

- **Prefer reputable, well-maintained npm packages over hand-rolling custom code** — faster delivery, battle-tested, fewer compatibility surprises. Before adding one: check weekly downloads, recent commit activity, TypeScript types, and bundle weight; skip abandoned or thin-wrapper packages. Only write custom when no solid package fits.
- The project uses Tailwind 3. Before writing any component look at:
  - `/apps/frontend/src/app/colors.scss`
  - `/apps/frontend/src/app/global.scss`
  - `/apps/frontend/tailwind.config.js`
  All `--color-custom*` are deprecated — don't use them. Check existing components first to get the right design.
- Backend layering: Controller >> Service >> Repository (no shortcuts). Sometimes Controller >> Manager >> Service >> Repository. Most server logic lives in `libs/server`; backend repos mostly write controllers and import from `libs/server`.
- Frontend: UI components in `/apps/frontend/src/components/ui`; routing in `/apps/frontend/src/app`; always fetch via SWR using the `useFetch` hook from `/libraries/helpers/src/utils/custom.fetch.tsx`.
- Each SWR call gets its own hook, complying with `react-hooks/rules-of-hooks` — never `eslint-disable-next-line` it. Valid: `const useCommunity = () => useSWR(...)`. Invalid: one hook returning an object of `useSWR` closures.
- Linting runs only from the repo root.
- The system is in production with many users — be sure changes don't break existing users; a migration may be needed.

## Loop memory (autopilot)

### Patterns
- Public (logged-out) routes must be allow-listed in `apps/frontend/src/proxy.ts` (~lines 46-55); everything else bounces logged-out visitors to `/auth`.
- Pricing/tier source of truth: `libraries/nestjs-libraries/src/database/prisma/subscriptions/pricing.ts`. Billing master switch = presence of `STRIPE_PUBLISHABLE_KEY`.
- Branding: "Cuanto Socials" via `isGeneralServerSide()` literal switch; accents `#10b981` / `#6366f1`; logo `components/ui/logo-text.component.tsx`.
- Landing building blocks: `components/landing/landing.page.tsx` + `campaigns.ts` (3 campaigns: creators, agencies, launch).

### Gotchas
- `pnpm test` is broken (root jest.config.ts imports @nx/jest which is not installed) — zero test files exist anyway. Do not use as gate.
- No typecheck/lint scripts anywhere; `tsgo` NOT installed on this PC — use `pnpm exec tsc`.
- Backend tsconfig has no include/files — `tsc -p apps/backend` sweeps dist/ and explodes. Only typecheck the frontend project.
- Windows PC: PowerShell 5.1 (no `&&`), git-bash available; `py -3` not python3. Prefer git-bash for POSIX-ish commands; cwd resets between Bash calls — use absolute paths or `cd` in compound commands.
- Production system with real users — additive changes only; don't alter authed-user flows.

### Recent Learnings
- Agent-tool worktree isolation cuts from stale base 1c8d9b88 (NOT current branch) in this repo — worktree branches diverge 100+ commits. Do NOT use isolation:worktree here; run implementers directly on the checkout (sequential) or cherry-pick/port their commits.
- Public pages: reuse components/marketing/marketing-nav|footer.component.tsx; add route to proxy.ts allow-list (~line 46-55) as exact-match line.
