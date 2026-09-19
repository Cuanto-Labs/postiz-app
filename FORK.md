# FORK.md — what this fork changes, and how to take upstream updates

This repo is **Cuanto Socials**, a fork of [gitroomhq/postiz-app](https://github.com/gitroomhq/postiz-app).
It exists so updates stay cheap: read this before customising anything, and run
`./scripts/fork-status.sh` before deciding to merge upstream.

## Where the fork stands (measured 2026-08-16, after the catch-up)

| | |
|---|---|
| Merged up to | upstream main **9ddbd73c** (2026-08-15, post-v2.23.0) |
| Behind | **0** upstream commits |
| Ahead | **84** local commits |
| Files only we touched | 180 (carry freely) |
| Brand-new files | 48 (zero merge risk) |

The catch-up merged 199 upstream commits. It was worth measuring first: the dry
run said 6 conflicting files, and 6 is what it was. Merging upstream *main* rather
than the v2.23.0 tag was deliberate — two LinkedIn page fixes and a non-axios SSRF
check landed after the tag, and LinkedIn is the only connected integration.

Only schema change in those 199 commits: `APPLE` added to the `Provider` enum.
Additive, so the startup `prisma db push` was safe.

## What we actually changed

1. **Branding** — "Postiz" → "Cuanto Socials" across UI copy.
2. **Plan-aware checkout funnel** — pricing cards carry the selected plan through
   signup into Stripe checkout.
3. **Temporal orchestrator** (`apps/orchestrator`) — replaces upstream's in-process
   scheduling for post publishing, plus worker-concurrency tuning for a ~6-user
   deployment. This is the deepest architectural divergence.
4. **Configurable AI provider pool** — `AGENT_BASE_URL` / `AGENT_API_KEY` /
   `AGENT_MODEL`, a dynamic `/copilot/models` endpoint, and an hourly AI rate limit.
5. **Integration control** — `ENABLED_INTEGRATIONS` boots 2 providers instead of 33,
   plus a Redis-backed live toggle (`GET/PUT /admin/integrations/enabled`) so
   enabling a network needs no redeploy.
6. **Deploy config** — `vercel.json` (frontend on Vercel, `/api/*` rewritten to the
   self-hosted backend), `Dockerfile` (builds as `www`, no post-build `chown -R`),
   `/monitor/uptime` off-fleet cron, and `proxy.ts` host handling for
   `api.socials.cuantolabs.com`.

Backend hosting and ops live outside this repo — see `postiz-stack.sh` in
`coding-scripts`. Backend runs as docker container `pz-app` on host deb
(compose `~/stacks-postiz.compose.yml`, source checkout `~/services/postiz`).

## The 6 files that conflict on every catch-up

Each is a deliberate edit to an upstream file. When merging, keep **both** sides —
upstream's fix plus our change — rather than picking one:

| File | Ours |
|---|---|
| `libraries/nestjs-libraries/src/temporal/temporal.module.ts` | worker concurrency + idle-memory tuning |
| `libraries/nestjs-libraries/src/integrations/integration.manager.ts` | `ENABLED_INTEGRATIONS` filter + Redis live toggle |
| `libraries/nestjs-libraries/src/agent/agent.graph.service.ts` | provider pool routing, `AGENT_MODEL` to the right provider |
| `libraries/nestjs-libraries/src/chat/load.tools.service.ts` | same provider-pool wiring |
| `apps/frontend/src/components/auth/login.tsx` | plan carried through signup |
| `apps/frontend/src/components/new-layout/layout.component.tsx` | plan-aware checkout funnel |

## Rules that keep merges cheap

1. **Never edit `locales/*/translation.json`.** Those files are upstream's and must
   stay byte-identical. The product name is substituted at load time in
   `libraries/react-shared-libraries/src/translation/brand.ts`, wired into
   `i18next.ts`. This alone removed 14 of the 20 conflicts, and it rebrands strings
   upstream adds later for free. Override the name with `NEXT_PUBLIC_BRAND_NAME`.
2. **Prefer a new file over editing an upstream one.** 45 of our files are additive
   and have never cost anything at merge time.
3. **Prefer env/config over code edits.** Points 4 and 5 above are configuration
   surfaces precisely so behaviour changes without touching upstream logic again.
4. **If you must edit upstream code, keep the hunk small and comment why**, so the
   next merge can tell intent from accident.
5. **Add new hardcoded UI copy through `brandString()`** rather than typing the
   product name, so it survives a rebrand and does not fight upstream.

## Taking an update

```bash
./scripts/fork-status.sh --merge     # what will conflict, before committing to anything
git checkout -b chore/upstream-v2.24
git merge upstream/main              # resolve the ~6 files, keeping both sides
pnpm install && pnpm run build       # build before deploying anything
postiz-stack.sh deploy               # rebuild the backend container from this branch
```

Verify after deploying: `postiz-stack.sh health` (container → funnel → Vercel →
frontend), then confirm a scheduled post still publishes — the publish path is the
one upstream changes most and the one a health check cannot see.

Merge cadence: no need to chase every release. The trigger that matters is a
provider fix — when posting to a network breaks, check
`git log upstream/main -- libraries/nestjs-libraries/src/integrations/social`
first, and cherry-pick if a full catch-up is not warranted.
