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
| `GET` | `/mobile/v1/me` | — (bearer) | `{ user, org, orgs, plan: { tier, options }, sessionId }` | current user, orgs, current org and plan tier + limits |
| `GET` | `/mobile/v1/config` | — (public, no bearer) | `{ minVersion, providers: Array<{ identifier, name }>, links: { support, terms, privacy } }` | min supported app version, enabled (non-hidden) providers, support/legal links |
| `GET` | `/mobile/v1/channels` | — (bearer) | `{ channels: Array<{ id, internalId, name, identifier, picture, disabled, refreshNeeded, inBetweenSteps, display, type, customer, limits: { maxCharacters, editor, media: MediaLimits } }> }` | connected channels with status and per-platform limits; `limits.media` (`maxImages`, `maxVideos`, `maxImageBytes`, `maxVideoBytes`, `maxVideoSeconds`, `imageMimes`, `videoMimes`, `aspectRatios?`) comes from `getMediaLimits(providerIdentifier)` |
| `GET` | `/mobile/v1/posts?from&to&customer` | `MobilePostsQueryDto` (`from`, `to` ISO dates, `customer?`) | `{ posts: [...] }` | list posts within a date window |
| `GET` | `/mobile/v1/posts/:group` | — (bearer) | post group detail | 404 `{ msg: 'Post not found' }` if the group doesn't exist |
| `POST` | `/mobile/v1/posts` | raw body (`posts[]`, `type`) | created post group | server-side validated (`PostValidationException` on empty content/settings/too-long unless `type: 'draft'`); optional `Idempotency-Key` header |
| `PUT` | `/mobile/v1/posts/:group` | raw body (`posts[]`, `type` defaults to `update`) | updated post group | same validation as create; optional `Idempotency-Key` header |
| `PATCH` | `/mobile/v1/posts/:group/date` | `MobileRescheduleDto` (`date` ISO date, `action?: 'schedule'\|'update'`) | `{ group, date }` | reschedules every root post (no `parentPostId`) in the group; 404 if group doesn't exist |
| `DELETE` | `/mobile/v1/posts/:group` | — (bearer) | `{ ok: true }` | deletes the post group |
| `PUT` | `/mobile/v1/push/devices` | `MobilePushDeviceDto` (`apnsToken`, `environment: 'sandbox'\|'production'`, `bundleId?`, `locale?`, `timezone?`, `prefs?`) | `{ device }` | upsert by `apnsToken` |
| `DELETE` | `/mobile/v1/push/devices/:token` | — (bearer) | `{ ok: true }` | unregisters the device, idempotent |
| `GET` | `/mobile/v1/push/prefs?token=` | `MobilePushPrefsQueryDto` (`token`) | `{ prefs }` | 404 unknown token |
| `PUT` | `/mobile/v1/push/prefs` | `MobilePushPrefsDto` (`apnsToken`, `prefs`) | `{ prefs }` | 400 unknown pref key |
| `POST` | `/mobile/v1/media/uploads` | `MobileMediaCreateUploadDto` (`fileName` ≤255, `contentType`, `size` int ≥1) | `CreateUploadResult` = `{ uploadId, key, partSize, parts: { partNumber, url }[], expiresAt }` | 400 `{ msg: 'Unsupported file type.' }` if extension/`contentType` mismatch or unknown ext; 400 `{ msg: 'File is too large.' }` if `size` exceeds the per-mime cap (10MB image / 1GB video) or needs more than 200 parts; part URLs are presigned R2 multipart-upload PUTs, 1h expiry |
| `POST` | `/mobile/v1/media/uploads/complete` | `MobileMediaCompleteUploadDto` (`key`, `uploadId`, `parts: { partNumber, etag }[]`, `originalName?`) | `{ media: { id, name, path, status, processingError, thumbnail } }` | completes the R2 multipart upload, then sniffs the first ~4KB with `file-type`; mismatch vs. the extension's expected mime → 400 `{ msg: 'File contents do not match declared type.' }` and the object is deleted; on success saves the media (queues the processing workflow when configured, so `status` may come back `processing`) |
| `POST` | `/mobile/v1/media/uploads/abort` | `MobileMediaAbortUploadDto` (`key`, `uploadId`) | `{ ok: true }` | aborts the R2 multipart upload; idempotent — an already-gone (`NoSuchUpload`) upload still returns `{ ok: true }` |
| `GET` | `/mobile/v1/media/:id/status` | — (bearer) | `{ id, name, originalName, path, thumbnail, alt, status, processingError }` | `status` is `processing` \| `ready` \| `failed`; poll until it leaves `processing`; 404 `{ msg: 'Media not found' }` if the id doesn't exist (or belongs to another org) |
| `GET` | `/mobile/v1/media?page=` | `MobileMediaListQueryDto` (`page?` int) | `{ pages, results: Array<{ id, name, originalName, path, thumbnail, alt, thumbnailTimestamp }> }` | 18 per page; excludes media still `processing` |
| `GET` | `/mobile/v1/account/deletion-preview` | — (bearer) | `AccountDeletionPreview` = `{ orgsToDelete: { id, name }[], orgsToLeave: { id, name }[] }` | orgs where the caller is the sole `SUPERADMIN` land in `orgsToDelete` (will be fully deleted); the rest land in `orgsToLeave` (caller just leaves) |
| `DELETE` | `/mobile/v1/account` | `MobileDeleteAccountDto` (`confirm`, must be exactly `'DELETE'`) | `{ ok: true, deletedOrgs, leftOrgs }` (both `{ id, name }[]`) | 400 if `confirm` isn't `'DELETE'`; `3/min` throttle; see `## Account deletion` for cascade order |

`MobileTokens = { accessToken, refreshToken, expiresIn, sessionId }`.
`MobileAuthResponse = MobileTokens & { user: { id, email, name?, lastName?, pictureId? }, orgs: Array<{ id, name, role, disabled }> }` (password stripped, disabled orgs filtered).

## Idempotency-Key

- Optional request header on `POST /mobile/v1/posts` and `PUT /mobile/v1/posts/:group` (`MobileIdempotencyInterceptor`).
- 8–128 chars; outside that range → `400 { msg: 'Invalid Idempotency-Key' }`.
- Scoped per org (`organizationId`) and per authenticated user: the stored key is `${req.user.id}:${key}`, so two different users in the same org reusing the same client-generated key never replay each other. 24h TTL (`IDEMPOTENCY_TTL_MS`).
- Same key + same request (method + path + body hash) → replayed: original status code and body returned, handler not re-run. The status returned on a hit is whatever `res.statusCode` was on the original call (e.g. if the handler didn't explicitly set `201`, a replay of a `POST` returns the default `200`, not `201`) — the interceptor never invents a status.
- Same key + different payload → `422 { msg: 'Idempotency-Key reused with a different payload' }`.
- Stored in the `IdempotencyKey` table (`libraries/nestjs-libraries/src/mobile/idempotency.repository.ts`); a concurrent duplicate write is swallowed (Prisma `P2002`), not treated as an error.

## Push

- Prefs keys: `post.published`, `post.failed`, `channel.reconnect_needed` — default on; set `false` to opt out.
- APNs categories: `POST_PUBLISHED`, `POST_FAILED`, `CHANNEL_RECONNECT` (one per prefs key, `CATEGORY_BY_KIND` in `push.service.ts`).
- Payload shape: `{ aps: { alert: { title, body }, sound, category, thread-id }, kind, link }`.
- `environment` on the device record (`sandbox`/`production`) selects the APNs host per device at send time.
- Registering a device token that's already bound to a different user re-assigns it to the new user (`upsertByToken` is keyed by `apnsToken`) — this is how account switching on the same device works; the previous owner stops receiving pushes to that token.
- `410`/`BadDeviceToken`/`Unregistered` from APNs → the device is soft-disabled (`disabledAt` is set) and it's dropped from future sends.
- `429`/`5xx` from APNs → 3 attempts with exponential backoff (`500ms * 2^attempt`); still failing after 3 → the send for that device is marked failed.
- Fan-out is per-org: `notifyOrg` loads every user in the notification's `orgId` via `OrganizationRepository.getAllUsersOrgs` and sends only to that org's active devices — users outside the org never receive the push.
- Push is fired from `NotificationService.inAppNotification` (`PushService.notifyFromNotification`), so the web notification feed and push stay in step — no separate push-only code path. The call is fire-and-forget (`void ... .catch(() => {})`): it never delays or blocks the email/workflow path that follows.
- No push is sent when `APNS_KEY_ID`/`APNS_TEAM_ID`/`APNS_PRIVATE_KEY` are unset (`ApnsClient` returns `not_configured`).

## Media upload

Client flow for `POST /mobile/v1/posts` attachments:

1. `POST /mobile/v1/media/uploads` with `fileName`, `contentType`, `size` → get back `uploadId`, `key`, `partSize` (8MB), and one presigned R2 `parts[].url` per part (1h expiry, `MAX_PART_COUNT = 200`).
2. `PUT` each part's bytes straight to its presigned URL and capture the response `ETag` header for every part.
3. `POST /mobile/v1/media/uploads/complete` with `key`, `uploadId`, and `parts: [{ partNumber, etag }]` (plus optional `originalName`) to finish the multipart upload. The server sniffs the uploaded bytes and 400s if they don't match the extension's declared mime.
4. Poll `GET /mobile/v1/media/:id/status` until `status` is `ready` (usable) or `failed` (`processingError` set) — normalizable video/image types are queued into a processing workflow and stay `processing` until that finishes; types with no processor configured resolve immediately.
5. `POST /mobile/v1/media/uploads/abort` with `key`, `uploadId` to cancel an in-progress multipart upload (e.g. the client gave up before `complete`).

Allowed mimes (by file extension): `.jpg`/`.jpeg` → `image/jpeg`, `.png` → `image/png`, `.gif` → `image/gif`, `.webp` → `image/webp`, `.avif` → `image/avif`, `.mp4` → `video/mp4`, and `.mov` → `video/quicktime` when a media processor is configured (`UploadFactory.processorEnabled()`). Size caps: 10MB for images, 1GB for video (`getMaxSize`).

Per-provider posting limits (`limits.media` on `GET /mobile/v1/channels`) narrow counts/duration/aspect-ratio on top of the global upload caps above — see `getMediaLimits`/`MEDIA_LIMITS` in `libraries/nestjs-libraries/src/mobile/media/media-limits.ts`.

## Account deletion

`DELETE /mobile/v1/account` (`MobileAccountService.deleteAccount`) cascades in this order:

1. For each org the caller is deleting (see sole-admin rule below): terminate its running Temporal workflows — `post_<id>` for queued posts, `media_<id>` for processing media.
2. Cancel the org's Stripe subscription at period end (`StripeService.setToCancel`); failure is logged and non-fatal, deletion continues.
3. Soft-delete the org's integrations and posts (`IntegrationRepository.deleteIntegrationsForAccount`).
4. Soft-delete the org's media (`softDeleteMedia`, sets `deletedAt`).
5. Delete the organization (`OrganizationRepository.deleteOrganization`).
6. For every other org the caller belongs to but isn't sole admin of: leave the org (`deleteTeamMember`) — the org and its data are untouched.
7. Revoke every `MobileSession` and `PushDevice` row for the user (hard delete — all devices/sessions everywhere, not just the caller's org).
8. Write an `AccountDeletionAudit` row: SHA-256 hash of `userId` only (no email/PII), plus the deleted/left org ids and `source: 'mobile'`.
9. Send a "your account has been deleted" confirmation email (fire-and-forget, only if an email provider is configured) — sent while the address is still valid, before anonymization.
10. Anonymize the `User` row: `email` → `deleted+<hash>@deleted.invalid`, `name`/`lastName`/`pictureId`/`password`/`bio` cleared, `providerId` replaced, `activated: false`, `deletedAt` set.

**Sole-admin rule:** `GET /mobile/v1/account/deletion-preview` computes, per org the caller belongs to, whether the caller is `SUPERADMIN` with no other non-disabled `SUPERADMIN` in that org — if so the org is fully deleted (`orgsToDelete`); otherwise the caller just leaves it (`orgsToLeave`).

**Retained:** the `AccountDeletionAudit` row (hashed `userId` only) and the anonymized `User` row (kept for referential integrity, no PII left).

## Pending (later milestones, not yet implemented)

- `GET /mobile/v1/channels/connect/:provider`
- `POST /mobile/v1/ai/*`

See `docs/IOS-APP-PLAN.md` §4 for the per-milestone route specs.

## Env vars

- `MOBILE_GOOGLE_CLIENT_ID` — required for `/auth/oauth/start` and `/auth/oauth/exchange` (Google PKCE flow).
- `MOBILE_GOOGLE_CLIENT_SECRET` — optional; only sent to Google's token endpoint if set (some OAuth clients are public/PKCE-only).
- `MOBILE_OAUTH_REDIRECT_URI` — Google redirect URI; defaults to `https://socials.cuantolabs.com/m/auth/callback` if unset.
- `MOBILE_APP_SCHEME` — app-side redirect target after the web OAuth hop.
- `APPLE_APP_BUNDLE_ID` — read by `apps/backend/src/services/auth/providers/apple.provider.ts` to add the native iOS bundle id as an extra accepted JWT audience for Sign in with Apple. **Drift:** `.env.example` documents `APPLE_BUNDLE_ID` (no `APP_`), which nothing reads — that key is unused. Set `APPLE_APP_BUNDLE_ID` for native Apple sign-in to work.
- `MOBILE_MIN_APP_VERSION` — minimum supported iOS app version returned by `/mobile/v1/config`; defaults to `1.0.0` if unset.
- `MOBILE_SUPPORT_URL` — support link returned by `/mobile/v1/config`; defaults to `https://socials.cuantolabs.com/support`.
- `MOBILE_TERMS_URL` — terms link returned by `/mobile/v1/config`; defaults to `https://socials.cuantolabs.com/terms`.
- `MOBILE_PRIVACY_URL` — privacy link returned by `/mobile/v1/config`; defaults to `https://socials.cuantolabs.com/privacy`.
- `APNS_KEY_ID` — APNs auth key id, minted in the Apple Developer portal; vault-only, pushed to the container via the compose env file + `--force-recreate`.
- `APNS_TEAM_ID` — Apple Developer team id.
- `APNS_PRIVATE_KEY` — the `.p8` PEM contents, newlines escaped as `\n`; vault-only.
- `APNS_DEFAULT_TOPIC` — bundle id used as the default APNs topic when a device didn't send one; defaults to `com.cuantolabs.socials`.
- `CLOUDFLARE_ACCOUNT_ID` — R2 account id used to build the S3-compatible endpoint (`https://<id>.r2.cloudflarestorage.com`) for mobile media uploads.
- `CLOUDFLARE_ACCESS_KEY` / `CLOUDFLARE_SECRET_ACCESS_KEY` — R2 S3 API credentials used to presign multipart upload/part URLs; vault-only.
- `CLOUDFLARE_BUCKETNAME` — R2 bucket the mobile upload service writes to.
- `CLOUDFLARE_BUCKET_URL` — public base URL prefixed onto the object key to build the media `location` returned on upload complete.

## Gate

```
bash scripts/mobile-gate.sh
```

Runs, in order: `prisma validate`, `tsc --noEmit -p apps/backend/tsconfig.mobile-gate.json` (fails if total errors > 7, or if any error is under `/mobile/`), then `pnpm exec jest -c apps/backend/src/api/routes/mobile/jest.config.cjs --passWithNoTests`.
