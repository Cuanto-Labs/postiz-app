# Mobile API

Backend surface consumed by the iOS app. Fork-only — none of this exists upstream.

## Base URL & auth

- Base URL: `https://api.socials.cuantolabs.com`
- Auth header: `Authorization: Bearer <accessToken>` — JWT, `aud=mobile`, `iss=cuanto-socials`, HS256, 15 min TTL (`ACCESS_TTL_SECONDS = 900` in `mobile-token.service.ts`).
- Org selection header: `showorg: <orgId>` — optional; if omitted the middleware picks the caller's first non-disabled org. If present and the org isn't one of the user's, `403`.
- Refresh: `refreshToken` is opaque (random 48 bytes, base64url), stored server-side only as a SHA-256 hash, 60-day (`REFRESH_TTL_DAYS = 60`) rotating token. Each `/auth/refresh` call issues a new refresh token and invalidates the old hash. Reuse of an already-rotated (previous-hash) refresh token revokes the whole session family (`revokeFamily`) and returns 401.
- Error body shape: `{ "msg": "<message>" }` (see `mobile-auth.middleware.ts`; some auth-service errors instead come through Nest's default `{ statusCode, message, error }` — not yet normalized, see gap note below).
- Status codes: `401` (missing/invalid/expired token, revoked/reused refresh token, session revoked), `403` (org header not in caller's orgs, no orgs at all).
- Throttle: all `/mobile/v1/auth/*` routes are `10/min/IP` (`ThrottlerRealIpGuard`, `@Throttle({ default: { limit: 10, ttl: 60000 } })`).

**Gap:** `/mobile/v1/auth/*` handlers throw plain `UnauthorizedException`/`ForbiddenException`/`BadRequestException` (default Nest body), while the auth *middleware* (applied to authenticated routes like `/devices`) wraps errors as `{ msg }`. Don't assume every 401/403 body has `msg` — check `error`/`message` too.

## Routes

| Method | Path | Request DTO | Response | Notes |
|---|---|---|---|---|
| `POST` | `/mobile/v1/auth/login` | `MobileLoginDto` (`email`, `password` ≥3 chars, `deviceId` ≤128, `deviceName?` ≤128) | `MobileAuthResponse` | 401 invalid credentials; 403 user not activated |
| `POST` | `/mobile/v1/auth/register` | `MobileRegisterDto` (extends `CreateOrgUserDto` + `deviceId`, `deviceName?`) | `MobileAuthResponse`, or `{ activate: true }` if email verification is on (`EmailService.hasProvider()`) | 403 registration disabled or bad invite code; 400 on `routeAuth` failure |
| `POST` | `/mobile/v1/auth/refresh` | `MobileRefreshDto` (`refreshToken` ≥32 chars) | `MobileTokens` | 401 invalid/expired/revoked/reused token |
| `POST` | `/mobile/v1/auth/logout` | `MobileLogoutDto` (`refreshToken`) | `{ ok: true }` | idempotent — unknown token still returns `{ ok: true }` |
| `POST` | `/mobile/v1/auth/apple/native` | `MobileAppleNativeDto` (`identityToken` ≥20 chars, `deviceId`, `deviceName?`, `fullName?`) | `MobileAuthResponse` | native Sign in with Apple; routes through `AuthService.routeAuth('APPLE', ...)` |
| `POST` | `/mobile/v1/auth/oauth/start` | `MobileOAuthStartDto` (`provider: 'google'`, `codeChallenge` 43–128 chars, S256 PKCE) | `{ url, state }` | 503 if `MOBILE_GOOGLE_CLIENT_ID` unset |
| `POST` | `/mobile/v1/auth/oauth/exchange` | `MobileOAuthExchangeDto` (`provider: 'google'`, `code`, `state`, `codeVerifier` 43–128 chars, `deviceId`, `deviceName?`) | `MobileAuthResponse` | 401 on bad/expired state, PKCE mismatch, or Google token-exchange failure |
| `GET` | `/mobile/v1/devices` | — (bearer) | `{ devices: MobileSession[] }` (each session plus `current: boolean`) | requires `MobileAuthMiddleware` |
| `DELETE` | `/mobile/v1/devices/:id` | — (bearer) | `{ ok: true }` | 404 if session doesn't exist or belongs to another user |

`MobileTokens = { accessToken, refreshToken, expiresIn, sessionId }`.
`MobileAuthResponse = MobileTokens & { user: { id, email, name?, lastName?, pictureId? }, orgs: Array<{ id, name, role, disabled }> }` (password stripped, disabled orgs filtered).

## Pending (later milestones, not yet implemented)

- `GET /mobile/v1/me`
- `GET /mobile/v1/config`
- `GET /mobile/v1/channels`
- `GET /mobile/v1/channels/connect/:provider`
- `GET|POST|PUT|PATCH|DELETE /mobile/v1/posts*`
- `POST /mobile/v1/media/uploads`
- `PUT|DELETE /mobile/v1/push/devices*`, `GET|PUT /mobile/v1/push/prefs`
- `DELETE /mobile/v1/account`
- `POST /mobile/v1/ai/*`

See `docs/IOS-APP-PLAN.md` §4 for the per-milestone route specs.

## Env vars

- `MOBILE_GOOGLE_CLIENT_ID` — required for `/auth/oauth/start` and `/auth/oauth/exchange` (Google PKCE flow).
- `MOBILE_GOOGLE_CLIENT_SECRET` — optional; only sent to Google's token endpoint if set (some OAuth clients are public/PKCE-only).
- `MOBILE_OAUTH_REDIRECT_URI` — Google redirect URI; defaults to `https://socials.cuantolabs.com/m/auth/callback` if unset.
- `MOBILE_APP_SCHEME` — app-side redirect target after the web OAuth hop.
- `APPLE_APP_BUNDLE_ID` — read by `apps/backend/src/services/auth/providers/apple.provider.ts` to add the native iOS bundle id as an extra accepted JWT audience for Sign in with Apple. **Drift:** `.env.example` documents `APPLE_BUNDLE_ID` (no `APP_`), which nothing reads — that key is unused. Set `APPLE_APP_BUNDLE_ID` for native Apple sign-in to work.

## Gate

```
bash scripts/mobile-gate.sh
```

Runs, in order: `prisma validate`, `tsc --noEmit -p apps/backend/tsconfig.mobile-gate.json` (fails if total errors > 7, or if any error is under `/mobile/`), then `pnpm exec jest -c apps/backend/src/api/routes/mobile/jest.config.cjs --passWithNoTests`.
