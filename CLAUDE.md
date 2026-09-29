# gitroom
(add a one-line description)

## Dev
- `pnpm run --filter ./apps/extension --filter ./apps/orchestrator --filter ./apps/backend --filter ./apps/frontend --parallel dev` — dev server (port 3000)
- `pnpm -r --workspace-concurrency=1 --filter ./apps/frontend --filter ./apps/backend --filter ./apps/orchestrator run build && pnpm run build:workflows` — production build
- `jest --coverage --detectOpenHandles --reporters=default --reporters=jest-junit` — tests
- `pnpm typecheck` — type check (tsgo --noEmit for speed)

## Environment
- `DATABASE_URL` — "postgresql://postiz-user:postiz-password@localhost:5432/postiz-db-local"
- `REDIS_URL` — "redis://localhost:6379"
- `JWT_SECRET` — "random string for your JWT secret, make it long"
- `FRONTEND_URL` — "http://localhost:4200"
- `NEXT_PUBLIC_BACKEND_URL` — "http://localhost:3000"
- `BACKEND_INTERNAL_URL` — "http://localhost:3000"
