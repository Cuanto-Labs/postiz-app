# AGENTS.md — loop memory (autopilot)

## Patterns
- Frontend is Next.js App Router at `apps/frontend/src/app` (repo CLAUDE.md's "Vite ReactJS" line is stale).
- Public (logged-out) routes must be allow-listed in `apps/frontend/src/proxy.ts` (~lines 46-55); everything else bounces logged-out visitors to `/auth`.
- Pricing/tier source of truth: `libraries/nestjs-libraries/src/database/prisma/subscriptions/pricing.ts`. Billing master switch = presence of `STRIPE_PUBLISHABLE_KEY`.
- Branding: "Cuanto Socials" via `isGeneralServerSide()` literal switch; accents `#10b981` / `#6366f1`; logo `components/ui/logo-text.component.tsx`.
- Landing building blocks: `components/landing/landing.page.tsx` + `campaigns.ts` (3 campaigns: creators, agencies, launch).
- Follow repo CLAUDE.md: tailwind 3, no npm UI components, SWR via useFetch, Controller>>Service>>Repository on backend.

## Gotchas
- `pnpm test` is broken (root jest.config.ts imports @nx/jest which is not installed) — zero test files exist anyway. Do not use as gate.
- No typecheck/lint scripts anywhere; `tsgo` NOT installed on this PC — use `pnpm exec tsc`.
- Backend tsconfig has no include/files — `tsc -p apps/backend` sweeps dist/ and explodes. Only typecheck the frontend project.
- Windows PC: PowerShell 5.1 (no `&&`), git-bash available; `py -3` not python3. Prefer git-bash for POSIX-ish commands; cwd resets between Bash calls — use absolute paths or `cd` in compound commands.
- Production system with real users — additive changes only; don't alter authed-user flows.

## Recent Learnings
- Agent-tool worktree isolation cuts from stale base 1c8d9b88 (NOT current branch) in this repo — worktree branches diverge 100+ commits. Do NOT use isolation:worktree here; run implementers directly on the checkout (sequential) or cherry-pick/port their commits.
- Public pages: reuse components/marketing/marketing-nav|footer.component.tsx; add route to proxy.ts allow-list (~line 46-55) as exact-match line.
