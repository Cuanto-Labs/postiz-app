#!/usr/bin/env bash
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR" || exit 1

echo "[mobile-gate] prisma validate"
pnpm exec cross-env DATABASE_URL="postgresql://user:pass@localhost:5432/db" prisma validate --schema ./libraries/nestjs-libraries/src/database/prisma/schema.prisma
PRISMA_STATUS=$?
if [ "$PRISMA_STATUS" -ne 0 ]; then
  echo "[mobile-gate] prisma validate FAILED"
  exit 1
fi

echo "[mobile-gate] backend typecheck (tsconfig.mobile-gate.json)"
TSC_OUTPUT="$(pnpm exec tsc --noEmit -p apps/backend/tsconfig.mobile-gate.json 2>&1)"
TOTAL=$(printf '%s\n' "$TSC_OUTPUT" | grep -c 'error TS')
MOBILE=$(printf '%s\n' "$TSC_OUTPUT" | grep 'error TS' | grep -c '/mobile/')

echo "[mobile-gate] TOTAL=$TOTAL MOBILE=$MOBILE"

if [ "$TOTAL" -gt 7 ]; then
  echo "[mobile-gate] tsc TOTAL errors ($TOTAL) exceed baseline (7)"
  printf '%s\n' "$TSC_OUTPUT"
  exit 1
fi

if [ "$MOBILE" -ne 0 ]; then
  echo "[mobile-gate] tsc errors under /mobile/ ($MOBILE) must be 0"
  printf '%s\n' "$TSC_OUTPUT"
  exit 1
fi

echo "[mobile-gate] jest (mobile)"
pnpm exec jest -c apps/backend/src/api/routes/mobile/jest.config.cjs --passWithNoTests
JEST_STATUS=$?
if [ "$JEST_STATUS" -ne 0 ]; then
  echo "[mobile-gate] jest FAILED"
  exit 1
fi

echo "[mobile-gate] all checks passed"
exit 0
