# Cuanto Socials for iOS — Development Plan

**Status:** draft v1 · **Written:** 2026-09-16 · **Owner:** Eliran
**Scope:** native iPhone app for Cuanto Socials (our Postiz fork), from backend prep through App Store launch and after.

---

## 0. Summary

- **What:** a native SwiftUI app to write, schedule, preview and track social posts, plus the phone-only features the website can't offer: a share extension, push alerts when a post publishes or fails, home-screen widgets, Shortcuts, and camera-roll media.
- **How:**
  - Built on **CuantoKit** (networking, Keychain, design system, OnyxMetric analytics, StoreKit), scaffolded and shipped with **ios-suite**, and laid out like ShulMaker and Zmanym (xcodegen, MVVM with Observation, Swift Testing).
- **Backend:** the app talks to `api.socials.cuantolabs.com`. A small set of new backend endpoints must ship first: mobile sign-in tokens, account deletion, push device registration and push sending, and a media status field.
  - They go in **new files only**, to keep upstream Postiz merges easy.
- **Apple-rule posture:** built from day one to pass review.
  - Real native features, not a website wrapper (4.2).
  - Our own Swift code, with no Postiz AGPL code inside the app.
  - No purchases in v1; subscriptions bought on the web still unlock (3.1.3(b)).
  - In-app account deletion (5.1.1(v)).
  - Sign in with Apple alongside Google (4.8).
  - Consent before AI features (5.1.2(i)).
  - A demo account for the reviewer.
- **Timeline (one developer plus agents):** about **10–12 weeks** to App Store 1.0. Details are in §12.

---

## 1. Goals, non-goals, success criteria

### Goals (1.0)
1. Sign in: email and password, Sign in with Apple, and Google.
2. Switch organizations.
3. See connected channels and connect a new one (in-app OAuth).
4. Write a post:
   - Text, images or video, one or several channels, each with its own text.
   - Accurate per-platform preview.
   - Draft, schedule or post now.
5. A calendar (day, week, month) that shows scheduled, published and failed posts, with drag-to-reschedule.
6. Post detail: status, preview link (`/p/[id]`), comments, basic stats.
7. Push notifications when a post publishes or fails, and when a comment arrives.
8. A **share extension**: share a photo, video, link or text from any app and it opens the composer.
9. **Widgets**: next scheduled posts (home and lock screen).
10. **App Intents / Shortcuts**: "Draft a post", "What's scheduled today".
11. AI help in the composer (copilot) behind a consent screen.
12. Account deletion, settings, sign out, and a list of signed-in devices.

### Non-goals (1.0)
- In-app purchases or paywalls (deferred, §9.3).
- An iPad-optimized layout; the app runs on iPad as a scaled iPhone app.
- Admin screens (turning integrations on or off, invite-code admin, team management beyond viewing).
- Detailed analytics dashboards (basic numbers only).
- Offline publishing. Drafts work offline; scheduling needs the network.
- Watch, Mac or visionOS apps.

### Success criteria
- Approved on the first or second submission, with no 4.2, 3.1.1 or 5.1.1 rejection.
- Crash-free sessions ≥ 99.5% (Apple's crash reports plus OnyxMetric).
- Share extension to scheduled post in ≤ 20 seconds, measured end to end on a device.
- Every post created in the app publishes through the same Temporal orchestrator path as the web, with no mobile-only publish code.
- An upstream Postiz catch-up after the mobile backend work adds **no** new entries to the "files that conflict on every catch-up" list in FORK.md.

---

## 2. Apple compliance matrix (design input, not an afterthought)

| Guideline | Risk | How we comply | Where |
|---|---|---|---|
| **4.2 / 4.2.2** Minimum functionality, repackaged website | High if lazy | Fully native UI. No `WKWebView` except for the OAuth sheet (`ASWebAuthenticationSession`) and for opening a preview link in Safari View. Share extension, widgets, push, Shortcuts, camera roll, haptics and drag-to-reschedule show real native value. | Phases 2–5 |
| **AGPL-3.0** (Postiz) vs App Store terms | Medium | The app is our own Swift code written against the HTTP API. We **do not** port TSX/TS from `apps/frontend`, `apps/sdk` or `libraries/*` line by line. Request and response shapes come from the API contract, not copied code. The backend stays AGPL, and its source stays available (the fork is public or can be offered). A lawyer check is optional before launch. | Whole project |
| **3.1.1** In-app purchase | High if we sell in the app | v1 has no purchase UI, no prices and no "upgrade" button outside the US. A web subscription unlocks features (3.1.3(b) multiplatform). US storefront only: an optional "Manage plan on web" link, which US rules have allowed since 2025. Re-check the current guideline text at submission. | §9.3 |
| **3.1.3(c)** Enterprise services | Low | Doesn't apply today (self-serve sign-up). Revisit if we move to sales-led org sales. | — |
| **5.1.1(v)** Account deletion | Certain rejection without it | New backend `DELETE /mobile/v1/account` with a real delete or anonymize, plus an in-app flow (Settings → Delete account → confirm → done). A web link alone is not enough. | Phase 1 + 4 |
| **4.8** Login services | Certain rejection without it | The backend already has an Apple provider (`apple.provider.ts`). Show Sign in with Apple wherever Google appears. Connecting LinkedIn or X to post is **not** login, so it's exempt. | Phase 2 |
| **5.1.2(i)** Sharing data with third-party AI | Medium | Before the first copilot use, a sheet naming the provider type ("third-party AI model"), what's sent (draft text, optional images), and a toggle. The consent is stored on the server per user. | Phase 4 |
| **5.1.1 / privacy labels / privacy manifest** | Medium | `PrivacyInfo.xcprivacy` for the app and every extension. Required-reason APIs (UserDefaults, file timestamps) declared. Nutrition labels: contact info, user content and identifiers, all "linked to user, not used for tracking". **No ATT prompt** (no tracking). OnyxMetric is first-party only. | Phase 6 |
| **1.2** User-generated content | Low–medium | The app writes posts to the user's own channels and shows comments on their own posts. Add "Report / Hide comment" on preview comments and a contact link (support@) to be safe. | Phase 4 |
| **5.2.1 / 5.2.2** IP and third-party trademarks | Medium | LinkedIn, X and similar logos only as small channel badges, following each brand's guidelines. No platform logo in the app icon, screenshots headline or name. Never say "LinkedIn app" or "official". No "Postiz" anywhere. | Phase 6 |
| **2.1** App completeness / reviewer access | High | Demo reviewer account with a pre-connected **test** LinkedIn page or profile, sample scheduled posts, and notes explaining the OAuth connect flow. | Phase 6 |
| **2.3** Accurate metadata | Low | Real-device screenshots of real features. The description matches what the app does. | Phase 6 |
| **4.5.4** Push notifications | Low | Push is opt-in, never required, and never used for marketing without separate consent. | Phase 3 |
| **Export compliance** | Low | Standard HTTPS only → `ITSAppUsesNonExemptEncryption = NO`. | Phase 0 |
| **Platform API terms** (not Apple) | Medium | LinkedIn API terms: no storing member data beyond what the web app already stores, and no scraping. Same for X. The app only shows what our backend already has. | Whole project |

**Re-check rule:** the App Review Guidelines change several times a year. Read the current text of 3.1, 4.2, 4.8, 5.1 and 5.2 in the week before submitting, and log the date checked in `docs/IOS-SUBMISSION-LOG.md`.

---

## 3. Architecture

### 3.1 Big picture

```
┌──────────────────────────── iPhone ────────────────────────────┐
│  CuantoSocials.app (SwiftUI)                                   │
│   ├─ Features: Auth · Channels · Composer · Calendar · Post    │
│   │            Detail · Notifications · Settings · Copilot     │
│   ├─ Core: SocialsAPI (CuantoNet) · Session (Keychain)         │
│   │        DraftStore (SwiftData) · MediaPipeline · Push       │
│   ├─ ShareExtension ──┐                                        │
│   ├─ Widgets ─────────┼─ App Group: group.com.cuantolabs.socials│
│   └─ AppIntents ──────┘   (shared Keychain access group + cache)│
└───────────────┬────────────────────────────────────────────────┘
                │ HTTPS  Authorization: Bearer <access>   showorg: <orgId>
                ▼
   api.socials.cuantolabs.com  (Tailscale Funnel → deb pz-app :4600)
   ├─ existing app routes (/posts, /integrations, /media, /copilot…)
   ├─ NEW /mobile/v1/* (auth tokens, devices, account delete, push prefs)
   └─ orchestrator (Temporal) ──► NEW PushService ──► APNs (HTTP/2, .p8)
```

### 3.2 Which backend API to use: decision

Three options:

| Option | Pros | Cons |
|---|---|---|
| A. Internal app routes (`/posts`, `/integrations`…) with cookie-style JWT sent as `auth` header | Complete feature coverage today | Not a stable contract. Upstream reshapes these routes whenever the web UI changes, so every catch-up can silently break the app. |
| B. Public API `/public/v1/*` with OAuth `pos_` tokens | Upstream-maintained, versioned, meant for outside clients | Tokens are **org-scoped** API access, not user sessions. It may be missing calendar, comments, copilot, notifications and org switching. |
| **C. Hybrid (recommended)** | Public v1 wherever it covers the need. A thin fork-owned **`/mobile/v1` facade** for the rest; each facade handler calls the existing services, not HTTP routes. | A small amount of new backend code (new files only). |

**Recommendation: C.** The facade is our own contract. When an upstream merge changes an internal service signature, it breaks **at compile time** in a file we own, not at runtime on users' phones. Phase 0 produces the exact endpoint-coverage table that decides which calls go where.

### 3.3 iOS tech choices

| Area | Choice | Why |
|---|---|---|
| Min iOS | **18.0** | Matches CuantoKit, and in Sept 2026 that covers the large majority of active iPhones. |
| Build SDK | Latest Xcode with the iOS 28 SDK | Apple requires the current SDK for submissions after its yearly cutoff. |
| UI | SwiftUI, `@Observable` view models, `NavigationStack` | Same as ShulMaker and Zmanym. |
| Language | Swift 6 strict concurrency | Same as CuantoKit. |
| Networking | `CuantoNet.APIClient` + `Endpoint<Response>` | Handles a 401 with a single shared token refresh; `MockTransport` for tests. |
| Secrets | `CuantoCore.KeychainStore`, shared access group | Token readable from the share extension, widgets and intents. |
| Local data | SwiftData for drafts and a read-through cache of calendar and channels | Offline drafts, instant launch. |
| Media | PhotosUI `PhotosPicker`, AVFoundation export, background `URLSession` uploads | Large videos survive the app going to the background. |
| Analytics | `CuantoAnalytics` → OnyxMetric only | Standing rule: no third-party analytics. |
| Crash reports | Apple's built-in crash reports (MetricKit + Xcode Organizer) | No Sentry or Crashlytics (same rule). |
| Push | Custom small `PushManager` modelled on ShulMaker's (not in CuantoKit yet). Extract it into `CuantoPush` in CuantoKit afterwards. | Reuse across apps. |
| Payments (later) | `CuantoStore` (StoreKit 2) | Already built. |
| Project | xcodegen `Project.yml` via `ios-new --with-widget` | Same as the existing apps. |
| Dependencies | None outside CuantoKit | Our containment policy. |

### 3.4 App module layout

```
ios/
├─ Project.yml
├─ App/                         # @main, AppDelegate (push), DI container, root router
├─ Sources/
│  ├─ Core/
│  │  ├─ API/                   # Endpoints grouped by domain, DTOs (Codable), APIError mapping
│  │  ├─ Session/               # SessionStore (tokens, current org), AuthCoordinator
│  │  ├─ Persistence/           # SwiftData models: DraftPost, CachedPost, CachedChannel
│  │  ├─ Media/                 # picker adapters, transcoder, UploadQueue (background URLSession)
│  │  ├─ Push/                  # PushManager, notification categories/actions
│  │  ├─ Platforms/             # per-network rules: char limits, media limits, preview renderers
│  │  └─ Shared/                # App Group paths, Keychain group, feature flags
│  ├─ Features/
│  │  ├─ Onboarding/  Auth/  OrgSwitcher/
│  │  ├─ Channels/              # list, connect (ASWebAuthenticationSession), reconnect-needed state
│  │  ├─ Composer/              # editor, per-channel customize, media tray, schedule sheet, preview
│  │  ├─ Calendar/              # day/week/month, drag to reschedule, filters
│  │  ├─ PostDetail/            # status timeline, comments, stats, share preview link
│  │  ├─ Notifications/         # in-app feed (existing Notifications model)
│  │  ├─ Copilot/               # consent, suggest/rewrite/hashtags
│  │  └─ Settings/              # account, devices, notifications prefs, delete account, legal
│  └─ DesignSystem/             # app-specific tokens on top of CuantoUI
├─ ShareExtension/
├─ Widgets/                     # UpcomingPostsWidget (home + lock screen), later Live Activity
├─ Intents/                     # AppIntents: DraftPostIntent, TodayScheduleIntent
├─ Tests/                       # Swift Testing unit tests (MockTransport)
└─ UITests/                     # critical flows on sim via ios-test
```

**Where the code lives:** a new folder `ios/` inside `cuanto-socials`, next to the backend, so API and app changes land in the same PR. Add `ios/` to the path filters for upstream-sync automation and Vercel `ignoreCommand`, so iOS-only commits don't redeploy the website.

### 3.5 Identifiers
- Bundle ID: `com.cuantolabs.socials`. Extensions: `.share`, `.widgets`, `.intents`.
- App Group: `group.com.cuantolabs.socials`. Keychain group: `8AWCD3T4B5.com.cuantolabs.socials.shared`.
- Team `8AWCD3T4B5`, manual signing, provisioning profiles minted with `ios-sign`.
- URL scheme: `cuantosocials://` (fallback only).
- **Universal Links** on `socials.cuantolabs.com` for the auth and connect callbacks (preferred, because a custom scheme can be hijacked by another app).

---

## 4. Backend work (fork, new files only)

Rule: everything goes in `apps/backend/src/api/routes/mobile/*`, `libraries/nestjs-libraries/src/mobile/*`, and new Prisma models **added at the end** of `schema.prisma`. Upstream files change only at a single registration line each (module imports), and each of those is listed in FORK.md.

### 4.1 Mobile sign-in tokens
The web sign-in today sets a JWT cookie (`auth`) and has no refresh token. A phone needs sign-ins that last and can be revoked.

- **New model `MobileSession`:**
  - Fields: `id`, `userId`, `deviceId`, `deviceName`, `refreshTokenHash`, `createdAt`, `lastUsedAt`, `expiresAt`, `revokedAt`.
- **Endpoints:**
  - `POST /mobile/v1/auth/login`: email and password → `{accessToken (JWT, 15 min), refreshToken (opaque, 60 days, rotating), user, orgs}`. It reuses `AuthService` checks (activation, invite code on register, disabled users).
  - `POST /mobile/v1/auth/register`: same body as web register, including invite code. It must respect whatever invite or waitlist gating the web uses.
  - `POST /mobile/v1/auth/oauth/start?provider=apple|google`: returns the provider URL. The redirect goes to the **universal link** `https://socials.cuantolabs.com/m/auth/callback`, which the app catches.
    - Use the existing `/auth/oauth-mobile-callback` and set `MOBILE_APP_SCHEME`. It currently falls back to `postiz://auth/callback`, which must change.
  - `POST /mobile/v1/auth/oauth/exchange`: `{provider, code, state, codeVerifier}` → tokens. **Add PKCE**; the existing `checkExists` path skips the state-cookie check when a `redirect_uri` is sent, so PKCE has to take its place.
  - `POST /mobile/v1/auth/apple/native`: accepts the **native** Sign in with Apple identity token (`ASAuthorizationAppleIDCredential`), verified against Apple's keys. This gives the native Apple button instead of a web sheet, which is the better experience and what Apple expects.
  - `POST /mobile/v1/auth/refresh`: rotating refresh. If an old refresh token is reused, revoke the whole session family.
  - `POST /mobile/v1/auth/logout`, plus `GET /mobile/v1/devices` and `DELETE /mobile/v1/devices/:id`.
- **Auth guard:** a new `MobileAuthMiddleware` accepts `Authorization: Bearer <access>` and fills the same `req.user` / `req.org` that `auth.middleware.ts` does, with the org taken from the `showorg` header. The existing controllers then work unchanged for any routes we reuse directly.
- **Access token:** signed with the existing JWT secret using a separate `aud: "mobile"` claim, so it can't be replayed as a web cookie, and web tokens aren't accepted as mobile ones.
- **Rate limits:** login, register and refresh through the existing throttler: 10 per minute per IP and 5 per minute per account.

### 4.2 Account deletion
- `DELETE /mobile/v1/account` (also offered on the web in Settings for consistency). Body: `{confirm: "DELETE", password? | recentAuth}`.
- Behavior:
  1. Cancel any Stripe subscription the user solely owns, at period end or right away (decide in §13).
  2. For each org:
     - If the user is the only admin, delete the org's integrations (revoke tokens with providers where the API allows), queued posts, media (R2 objects) and webhooks.
     - Otherwise just remove the membership.
  3. Delete or anonymize the `User` row, delete sessions, delete push devices.
  4. Send a confirmation email.
- Queued posts: cancel them in Temporal, not only in the DB, so nothing publishes after deletion.
- Log an audit row (user id hash + timestamp) to prove the deletion.
- **This must be live before the first submission.**

### 4.3 Push notifications
- **Model `PushDevice`:** `id`, `userId`, `orgId?`, `apnsToken`, `environment (sandbox|production)`, `bundleId`, `locale`, `timezone`, `prefs JSON`, `lastSeenAt`, `disabledAt`.
- **Endpoints:**
  - `PUT /mobile/v1/push/devices`: upsert by token.
  - `DELETE /mobile/v1/push/devices/:token`
  - `GET|PUT /mobile/v1/push/prefs`
- **`PushService`:** APNs over HTTP/2 with token auth (a `.p8` key).
  - Use Node's built-in `http2`, following ShulMaker's pattern; no new package if possible.
  - Handle 410 Unregistered by disabling the device, and 429 or 5xx with backoff.
- **Where pushes fire:**
  - The Temporal orchestrator publish activity **on success** → `post.published` (deep link to the post).
  - **On final failure** → `post.failed`, with the reason and a "Retry" action.
  - A channel needing re-auth (refresh-token failure) → `channel.reconnect_needed`.
  - A new comment on a preview → `comment.created`.
  - Hook into the **existing `NotificationService`**, which already writes the in-app `Notifications` rows, so the web feed and push stay in step. Push is one more delivery channel.
- **Notification categories:** `POST_FAILED` (actions: Retry, Open), `POST_PUBLISHED` (Open, Share link), `CHANNEL_RECONNECT` (Reconnect).
- **Secrets:**
  - The APNs key id, team id and `.p8` go in Vaultwarden and are handed to the container through the compose env file.
  - Recreate the container with `--force-recreate` afterwards (a restart doesn't reload env_file; see `postiz-r2-token-rotation`).
- **Manual step:** minting the APNs `.p8` key in the Apple Developer portal has **no API**, so it's a one-time task for Eliran. Check first whether the ShulMaker key can be reused: one team key works for every app on the team.

### 4.4 Media for mobile
- Confirm which upload path works with bearer auth: `POST /media/upload-simple` or the public v1 upload. Also check the R2 size limits.
- Big videos: add a **presigned direct-to-R2 multipart upload**.
  - `POST /mobile/v1/media/uploads` → `{uploadId, parts[] presigned URLs}`, then `POST …/complete`.
  - The phone uploads parts in the background, and the backend never streams the bytes. This avoids Funnel and proxy body limits.
- Media processing state:
  - The upstream `Media.status` / `processingError` columns were added in the recent merge on `main`, but the local checkout here is on an older branch. Confirm against `origin/main`.
  - The app polls or receives a push while video processing runs, and shows "Processing…" on the media tile.
- Per-platform validation (size, aspect ratio, length, format) is **also** enforced on the server; the app checks early for a better experience, but the server is the source of truth.

### 4.5 Calendar and post endpoints (facade if public v1 falls short)
- `GET /mobile/v1/posts?from&to&channels[]&status[]`: a lean list DTO (id, group, channel, status, publishDate, first 140 characters, thumbnail URL, error). Pages by date window.
- `GET /mobile/v1/posts/:group`: full detail, including per-channel values and settings.
- `POST /mobile/v1/posts` and `PUT /mobile/v1/posts/:group`: calls the same `PostsService.createPost` the web uses. Adds an **`Idempotency-Key` header**, so retries on a flaky network don't create duplicate posts.
- `PATCH /mobile/v1/posts/:group/date`: reschedule. Make sure the `fix/change-date-null-post` branch fix is merged first.
- `DELETE /mobile/v1/posts/:group`
- `GET /mobile/v1/channels`: integrations plus `disabled`, `refreshNeeded`, avatar, provider identifier, and per-provider limits (so the app doesn't hardcode them).
- `GET /mobile/v1/me`: user, orgs, role, plan tier and limits (from `permissions.service.ts`), AI credits, feature flags.
- `GET /mobile/v1/config`: minimum supported app version (for a forced-update prompt), enabled providers (`ENABLED_INTEGRATIONS` + the Redis toggle), and links to support, terms and privacy.

### 4.6 Connecting a channel from the app
The provider OAuth apps (LinkedIn, X…) have fixed redirect URIs on the web domain. Plan:

1. The app calls `GET /mobile/v1/channels/connect/:provider` → the backend returns the provider auth URL built exactly as the web does. It adds `mobile=1` to the saved state, with a nonce tied to the mobile session.
2. The app opens it in `ASWebAuthenticationSession` (callback: universal link or `cuantosocials`).
3. The provider redirects to the **existing web callback page**, which runs `POST /integrations/social-connect/:integration` as today.
4. Once it succeeds, that page checks the state for `mobile=1` and **redirects to** `https://socials.cuantolabs.com/m/connected?status=ok&id=…`. The universal link is caught by the session, and the app refreshes its channel list.

Frontend change: one small branch in the callback page, plus the `/m/*` routes and `apple-app-site-association` served from `apps/frontend/public/.well-known/`. No new provider redirect URIs are needed, so nothing has to be re-approved by LinkedIn.

Pages with multiple accounts (the "pick which page" step): show a native picker using the existing "customer/pages" endpoints if they're reachable. Otherwise fall back to finishing that step in the web sheet.

### 4.7 AI (copilot)
- Reuse `/copilot/*` through the mobile guard. Add a lean `POST /mobile/v1/ai/suggest` with `{mode: rewrite|shorten|hashtags|ideas, text, channel}` if the chat endpoint's streaming format is awkward on iOS.
- **Consent:** `User.aiConsentAt` (a new field or a side table) is required. The server refuses AI calls until consent is recorded; the app's sheet sets it.
- Respect the existing hourly AI limit and credits; show remaining credits in the UI.
- Keep AI provider costs on the current pool config; don't add providers for mobile.

### 4.8 Hygiene
- API versioning: the `/mobile/v1` prefix. Breaking changes → `/mobile/v2`, keeping v1 for at least two app versions, enforced by the `minVersion` in `/config`.
- OpenAPI: add Nest swagger decorators to the mobile controllers and generate `ios/Sources/Core/API/openapi.json`.
  - A contract test in CI fails if the backend DTOs drift from what the app decodes.
- Security review (`security-reviewer` agent) of 4.1–4.3 before merging: token handling, PKCE, refresh reuse detection, deletion completeness, and preventing requests to other orgs by switching `showorg` without membership.
- Tests: Jest unit tests for token rotation, reuse detection, deletion cascade and push delivery (mocked APNs).
- Update FORK.md: new section "Mobile API (fork-only)" listing the registration touch-points.

---

## 5. iOS features in detail

### 5.1 Onboarding and sign-in
- First launch: a three-panel intro (schedule everywhere, share from any app, get notified), then sign-in.
- Buttons: **Sign in with Apple** (native), **Continue with Google** (ASWebAuthenticationSession + PKCE), email and password, "Create account" (with an invite code field if the backend requires one).
- After sign-in: org picker if there's more than one org. Then the notification permission **pre-prompt** screen explaining value before the system prompt, only at a meaningful moment (after the first scheduled post, not at launch).
- Session: access token in memory plus Keychain; refresh in Keychain (`AfterFirstUnlock`, shared access group). Single shared refresh on 401 (built into CuantoNet).
- Forced update: if `/config.minVersion` is higher than the installed version, show a blocking sheet with an App Store link.

### 5.2 Channels
- List with avatar, name, provider badge, status (OK / needs reconnect / disabled by admin).
- Connect flow as in §4.6. Reconnect uses the same flow.
- Disconnect needs confirmation and is admin-only (the role comes from `/me`).
- Empty state: a big "Connect your first channel" button.

### 5.3 Composer (the core screen)
- **Editor:**
  - One global text plus optional per-channel overrides (tabs).
  - A live character counter per channel (limits from `/channels`).
  - Link detection.
  - @mentions only where the provider supports them (later).
- **Media tray:**
  - `PhotosPicker` (multiple selection), camera capture, Files import.
  - Reorder by drag; crop or aspect presets per platform; alt text field.
  - Video trim (AVFoundation) and automatic H.264/HEVC → platform-safe export.
- **Channel selector:** chips; long-press shows a preview for that channel.
- **Preview:** native SwiftUI renderers that closely match a LinkedIn feed card and an X post (text truncation, "see more", image grid). Built from our own layouts, not screenshots or platform assets.
- **Schedule sheet:**
  - Now / pick a date and time / "next free slot" (existing `find-slot`).
  - Timezone shown explicitly (the user's timezone; the default display for Eliran is EST).
  - Repeat not in v1.
- **Actions:** Save draft (local immediately, server sync), Schedule, Post now. Idempotency key per composer session.
- **Drafts:** SwiftData autosave every few seconds and when the app goes to the background; server draft sync once online; conflicts resolved by last-write-wins with a "restored draft" banner.
- **Copilot button:** rewrite, shorten, hashtags, ideas → diff-style accept or reject. Consent on first use (§4.7).
- **Validation before submit:** per-channel limits, missing media for media-required platforms, reconnect-needed channels (block with a fix-it link).

### 5.4 Calendar
- Views: agenda list (default, fastest), week grid, month dots. Filter by channel and status.
- Drag a post to another time slot (week view) → haptic → optimistic update → `PATCH date` → roll back with a toast on error.
- Status colors: scheduled, published, failed (red, with a retry button), draft.
- Pull to refresh; cached data shows instantly from SwiftData.
- Deep links: `cuantosocials://post/<group>` and a universal link `https://socials.cuantolabs.com/m/post/<group>`.

### 5.5 Post detail
- Timeline: created → scheduled → publishing → published/failed (with error text in plain language; map provider error codes).
- Per-channel result with a "View on LinkedIn" link (opens the provider URL).
- **Share preview link** (`/p/[id]`) via the system share sheet; this page loads again as of today's fix.
- Comments from the preview page, with reply, hide and report (§2, 1.2).
- Basic stats if the analytics endpoint returns them (impressions, reactions); otherwise hide the section.
- Actions: duplicate, edit (if not published), delete, retry (failed).

### 5.6 Share extension
- Accepts images, movies, URLs and plain text (`NSExtensionActivationRule` with sensible maximums: 10 images, 1 video).
- A lightweight SwiftUI composer inside the extension (memory limit about 120 MB, so no heavy transcoding there):
  - Save as draft, or schedule quickly to default channels.
  - Big media → copy into the App Group container and hand off to the main app's background upload queue.
- Needs the shared Keychain token; if signed out → "Open Cuanto Socials to sign in".

### 5.7 Widgets and Live Activity
- **Upcoming posts widget:** small (next post time + channel), medium (next 3), lock-screen inline and rectangular.
  - Timeline from an App Group cache refreshed by the app and by silent push (`content-available`) when the schedule changes.
- **Later (1.1): Live Activity** "Publishing now…" for Post-now actions with large videos, ending with ✓ or ✗.
- Widget traps from memory: one provisioning profile per target, and xcodegen owns Info.plist (edit `Project.yml`).

### 5.8 App Intents / Shortcuts / Siri
- `DraftPostIntent(text, channels?)`, `SchedulePostIntent(text, date, channels)` (confirmation required), `TodayScheduleIntent` (spoken summary).
- `AppShortcutsProvider` phrases: "Draft a post in Cuanto Socials", "What's scheduled today in Cuanto Socials".
- Spotlight: index upcoming posts (Core Spotlight) → open detail.

### 5.9 Notifications (in-app feed)
- List backed by the existing `GET /notifications/list`; unread badge; tap → deep link.
- Settings → per-type push toggles (synced to `/push/prefs`).

### 5.10 Settings
- Account (name, email, avatar), current org and switcher, plan (read-only text, **no price or upgrade button** outside allowed storefronts).
- Devices (list and revoke sessions), notification preferences, AI consent toggle, appearance (system / light / dark).
- Legal: privacy policy, terms, open-source notices (CuantoKit credits; note that the server is AGPL with a link to the source).
- Support: email link, app version and build, "Copy diagnostic info" (no secrets).
- **Delete account** (§4.2) → a two-step confirm → signed out → farewell screen.

### 5.11 Accessibility and localization
- Dynamic Type through xxxLarge must not truncate primary actions. Enforced by the `ios-layout-check --design` gate.
- VoiceOver labels on every icon button, the calendar rotor for posts, and a Reduce Motion variant of drag animations.
- String Catalog from day one. English only in 1.0; Hebrew and Spanish later (right-to-left check for Hebrew).

---

## 6. Data and state management

- **Source of truth:** the server. SwiftData is a cache plus the outbox for drafts and pending actions.
- **Outbox pattern:**
  - Every change (create, reschedule, delete) is saved as a `PendingAction` with an idempotency key.
  - It is retried with backoff by a `SyncEngine` actor when the network returns (`NWPathMonitor`).
  - The UI shows "Syncing…" or "Failed — tap to retry".
- **Cache keys** are always scoped by `orgId`. Switching org swaps the cache view; sign-out wipes all org caches and the App Group widget cache.
- **Background refresh:** a `BGAppRefreshTask` every ~2 hours pre-fetches the next 7 days for widgets.
- **Timezones:** everything is stored as UTC on the wire and shown in the device timezone, with an explicit timezone label in the schedule sheet.

---

## 7. Security and privacy

- Tokens only in Keychain with the shared access group; never in UserDefaults, logs or analytics.
- No certificate pinning (Funnel and Vercel certificates rotate, and a pin failure would lock out every user). Rely on ATS defaults plus HSTS instead.
- `showorg` requests to another org are blocked on the server (§4.8 review item).
- Screenshots in the app switcher: blur the composer when there's unsent text (optional setting).
- OnyxMetric events: screen views and feature usage (`composer_open`, `post_scheduled`, `share_ext_used`) with **no post text, no media and no channel names**. Opt-out toggle in Settings.
- Logging: `os.Logger` with privacy annotations (`.private` for user content).
- Privacy manifest for each target; the third-party SDK list is empty.
- Jailbreak detection: none; low value for this app.
- Secrets for build and CI are vault-only (ASC key `fleet-ci`, APNs key); nothing in the repo.

---

## 8. Design

- The brand comes from the web: colors and logo from the Cuanto Socials brand, and `LogoTextComponent` equivalents as vector assets exported from the web SVG (made by us, not Postiz's).
- CuantoUI tokens with app-specific accents; SF Symbols for icons; platform badges follow each network's brand-asset rules (small, unmodified).
- App icon: a Cuanto Socials mark, no platform logos. Get 3 variants rendered and **sent to Eliran's phone to decide** (`sendit`/`wa`), not ASCII mockups.
- Light and dark mode from day one; test both in the design gate matrix.
- Key screens to design first, as rendered SwiftUI previews sent to the phone: Composer, Calendar week, Post detail, Share extension, Widget.
- Haptics: success when scheduling, warning on validation errors, a light tick while dragging.

---

## 9. Monetization and entitlements

### 9.1 v1 behavior
- The app reads `plan` and `limits` from `/me` and enforces them in the UI (for example "Your plan allows 5 channels").
- When a limit is hit: a neutral message ("You've reached your plan's limit") with **no price, no buy button and no external link** outside allowed storefronts.
- Web sign-ups and web subscriptions work as normal (3.1.3(b)).

### 9.2 US storefront external link (optional, 1.0 or 1.1)
- If the device's storefront is the US (`Storefront.current?.countryCode == "USA"`), show "Manage plan at socials.cuantolabs.com" as an external link.
- Re-check the current guideline and any required entitlement or disclosure sheet at build time; the rules moved in 2025 and may move again.

### 9.3 In-app purchase (later, only if data says mobile sign-ups need it)
- `CuantoStore` with StoreKit 2 subscriptions mirroring the web tiers.
- Backend: an App Store Server Notifications v2 endpoint (`/mobile/v1/appstore/notifications`) plus the App Store Server API to verify → map to a `SubscriptionTier` in the same table Stripe writes.
- Conflicts: if a user has both Stripe and Apple subscriptions, show "managed by App Store" or "managed by web" and never double-charge; the entitlement comes from whichever is active.
- Price: Apple takes 15% (Small Business Program; enroll first) → set iOS prices accordingly or keep them equal.
- Decision gate: after 60 days on the store, check how many in-app sign-ups hit plan limits and don't convert on the web.

---

## 10. Environments, testing and quality

### 10.1 Environments
| Env | Backend | Used for |
|---|---|---|
| Local unit | `MockTransport` fixtures (JSON recorded from staging) | `swift test`, fast, no sim |
| **Staging** | New `pz-staging` compose project on deb: its own Postgres DB, its own Redis, the Temporal namespace `staging`, `api-staging.socials.cuantolabs.com` over Funnel/CF, **memory-capped** (deb has no swap; watch `deb-governor`) | Contract tests, sim E2E, TestFlight internal builds |
| Production | Current pz-app | TestFlight external and the App Store |

The build configuration picks the base URL (`Debug-Staging`, `Release-Staging`, `Release`). The staging app has a different icon badge and bundle suffix `.staging`, so both can be installed side by side.

**Test channels:** a dedicated LinkedIn test page or profile and an X test account connected in staging (vault items). Never post test content to Cuanto Labs' real pages.

### 10.2 Test layers
1. **Unit (Swift Testing):**
   - DTO decoding against recorded fixtures, per-platform validation rules, outbox retry and idempotency, and the refresh single-flight.
   - The drag-reschedule optimistic update and its rollback.
   - Use `Clock` injection. **Never** busy-wait polling (the CuantoKit livelock lesson).
2. **Contract:** CI generates the OpenAPI from the backend, and a Swift test decodes sample responses from the **staging** backend nightly → alerts on drift after upstream merges.
3. **Backend Jest:** token rotation, deletion cascade, push sender, facade permissions.
4. **UI and E2E (sim, via `ios-test`):**
   - Sign in → connect (stubbed) → compose with image → schedule → appears in calendar → reschedule → delete.
   - Share-extension draft, delete account on a throwaway user.
   - One simulator at a time on Mini (sim lock); use `--light` when contended.
5. **Design gate:** `ios-design-lint` + `ios-layout-check --design` (sizes: SE, standard, Pro Max; Dynamic Type L / xxxL / AX3; light and dark).
6. **Device checks (Eliran's iPhone, only after the sim E2E passes):** real push delivery, share extension from Photos, a big video upload in the background, widget refresh, Sign in with Apple.
7. **Beta:** TestFlight Internal (auto-installs → **always archive from `main`**, never a feature branch), then an External group (the ~6 current web users) for at least 1 week before submitting.

### 10.3 Definition of done (per feature)
- Unit tests and the UI-test path pass; the design gate is green; screenshots at desktop-equivalent sizes (iPhone SE + Pro Max) are attached to the PR.
- `typescript-reviewer` (backend) and `code-reviewer` pass; `security-reviewer` for anything touching auth, tokens or media.
- An OnyxMetric event exists for the feature; the string catalog is updated; accessibility labels are present.

---

## 11. Build, sign, ship (ios-suite)

- Scaffold: `ios-new CuantoSocials --with-widget` → then add the Share and Intents extension targets in `Project.yml`.
- Machine check: `ios-doctor` on Mini.
- Signing: `ios-sign` (ASC API key `fleet-ci`) mints the certificate and a **provisioning profile per target** (app, share, widgets, intents). Unlock the login keychain before any headless `codesign`, or it fails with `errSecInternalComponent`.
- Archive and upload: `ios-preflight` → `ios-ship` from a clean `main` checkout only.
- Store listing: `ios-asc` for listing, age rating (4+), pricing (free), screenshots, submit.
  - The mutating ASC paths in ios-suite were only dry-run-tested; the **first real run on this app needs a careful human-watched pass**, and bugs found get fixed in ios-suite itself.
- After approval: **check app availability is set (`appAvailabilityV2`)**. "Approved" ≠ live in any country (lesson from an earlier app).
- Version scheme: `1.0.0 (build = UTC timestamp or CI run number)`; the minimum supported version is kept in backend `/config`.
- CI (later, optional): a GitHub Actions macOS job for `swift test` + backend contract tests on PRs touching `ios/**` or `apps/backend/src/api/routes/mobile/**`. Archiving stays on Mini.

---

## 12. Phased roadmap

Estimates assume one developer driving agents (implementer for code, reviewers as gates), part-time around other work. Dates are targets, not promises.

### Phase 0 — Groundwork (week 1)
- [ ] Confirm the local checkout is on `origin/main` (the local clone is on `fix/change-date-null-post` with local edits by another session; don't disturb it, use a worktree).
- [ ] Merge the `fix/change-date-null-post` fix if it's still pending (reschedule depends on it).
- [ ] **API coverage spike:** a table of every app action → public v1 / existing route / needs facade. Test bearer auth against each.
- [ ] Check whether `/oauth/authorize` + `/oauth/token` support PKCE and user-level (not only org-level) tokens. Record the result.
- [ ] Reserve the name "Cuanto Socials" in App Store Connect and register bundle IDs, the App Group and the Keychain group.
- [ ] Decide on universal link paths; add `apple-app-site-association` to the frontend `public/.well-known/` (deploys with Vercel).
- [ ] Stand up `pz-staging` on deb (memory-capped) + a staging DNS name + test channel accounts in the vault.
- [ ] Write `docs/IOS-SUBMISSION-LOG.md` and `docs/MOBILE-API.md` skeletons.
- **Exit:** coverage table approved; staging reachable; identifiers registered.

### Phase 1 — Backend mobile foundation (weeks 2–3)
- [ ] `MobileSession` model + login/register/refresh/logout/devices (§4.1), native Apple and Google PKCE.
- [ ] `MobileAuthMiddleware` + org header checks + rate limits.
- [ ] `DELETE /mobile/v1/account` with the full cascade + Temporal cancellation (§4.2).
- [ ] `/mobile/v1/me`, `/config`, `/channels`, `/posts` facade with idempotency (§4.5).
- [ ] OpenAPI generation; Jest tests; `security-reviewer` pass.
- [ ] Deploy to staging → then prod (behind no UI, harmless). FORK.md updated.
- **Exit:** a curl script signs in, lists channels, creates, reschedules and deletes a post, and deletes a throwaway account on staging.

### Phase 2 — App skeleton and sign-in (weeks 3–4)
- [ ] `ios-new` scaffold, `Project.yml` targets, CuantoKit dependency, environments and build configurations, staging icon.
- [ ] Session store, API client, DTOs from OpenAPI, error mapping, forced-update check.
- [ ] Onboarding, sign in (Apple native, Google, email), register with invite code, org switcher.
- [ ] Channels list (read-only) + empty states.
- [ ] Unit tests + first sim E2E (sign-in) + design gate green.
- **Exit:** TestFlight Internal build 0.1 signs in and shows channels on Eliran's phone.

### Phase 3 — Compose, schedule, push (weeks 5–7)
- [ ] Composer: editor, per-channel overrides, limits, media picker, image pipeline, preview renderers (LinkedIn, X).
- [ ] Media upload: small files direct; presigned multipart + background URLSession for video (§4.4).
- [ ] Schedule sheet with find-slot; drafts (SwiftData) + outbox sync engine.
- [ ] Calendar (agenda + week + month), drag to reschedule, post detail, retry failed, share preview link.
- [ ] Backend push: `PushDevice`, `PushService`, hooks in the orchestrator and NotificationService; APNs key in the vault (**needs Eliran to mint the `.p8`, or confirm the ShulMaker key is reused**).
- [ ] App push: permission pre-prompt, registration, categories and actions, deep links.
- **Exit:** from the phone, schedule a post with an image to the staging test LinkedIn page → a push arrives when it publishes → tap opens the detail.

### Phase 4 — Native value and compliance features (weeks 7–9)
- [ ] Channel connect in the app (§4.6) incl. the frontend callback bounce + universal links.
- [ ] Share extension (§5.6).
- [ ] Widgets (home + lock screen) + background refresh (§5.7).
- [ ] App Intents / Shortcuts / Spotlight (§5.8).
- [ ] Copilot with the consent sheet and server-side consent (§4.7).
- [ ] Notifications feed, settings, devices, **delete account flow**, comment report/hide, legal and open-source notices.
- [ ] OnyxMetric events + opt-out.
- **Exit:** every 1.0 goal in §1 works on staging; the full E2E suite passes on the sim.

### Phase 5 — Hardening (weeks 9–10)
- [ ] Accessibility pass (VoiceOver walkthrough of every screen), Dynamic Type AX sizes, Reduce Motion.
- [ ] Performance: cold launch < 1.5 s on an older device, calendar scroll at 60 fps with 500 posts, memory in the share extension < 80 MB.
- [ ] Network chaos: airplane mode mid-upload, token expiry mid-request, backend 502 (deb restart), org removed while the app is open.
- [ ] Upstream sync rehearsal: merge the latest Postiz into a branch → run contract tests → confirm the mobile API still compiles and passes.
- [ ] Security review of the whole app + backend facade; fix findings.
- [ ] Device checks on Eliran's iPhone (only after sim E2E is green).
- **Exit:** zero P0/P1 bugs; checklists signed off.

### Phase 6 — Store prep and beta (weeks 10–11)
- [ ] Privacy manifests, nutrition labels, export compliance flag.
- [ ] Privacy policy and terms pages on socials.cuantolabs.com updated for mobile (push, device IDs, AI sharing, deletion).
- [ ] Reviewer demo account on **production** with a pre-connected test channel and sample posts; review notes explaining the connect flow and that posting goes to the account's own channels.
- [ ] Screenshots (6.9" + 6.5" sizes as ASC requires), app preview video optional, description, keywords, support URL, marketing URL, age rating, category (Productivity or Social Networking — pick Productivity to avoid extra social-app scrutiny).
- [ ] Re-read the current guidelines 3.1, 4.2, 4.8, 5.1 and 5.2; log the date.
- [ ] TestFlight External with the current web users for ≥ 7 days; fix feedback.
- **Exit:** a build from `main` is uploaded and all metadata is complete.

### Phase 7 — Submit and launch (week 12)
- [ ] Submit (manual release). Answer any rejection within 24 h; common fixes are pre-drafted (§14).
- [ ] After approval: **verify availability in countries** + a storefront lookup, then release.
- [ ] Launch posts via Cuanto Socials itself (LinkedIn), a website banner "Get the iPhone app" (smart app banner meta tag on socials.cuantolabs.com).
- [ ] Watch crash reports, OnyxMetric funnels and backend logs for `/mobile/v1` errors for 72 h.

### Phase 8 — After launch (1.1+)
- Live Activity for publishing; iPad layout; more networks as `ENABLED_INTEGRATIONS` grows; richer analytics; Hebrew and Spanish localization; team approval workflows; Apple Watch "next post" complication; decide on IAP (§9.3); extract `CuantoPush` + a sign-in module into CuantoKit for reuse in ShulMaker and Zmanym.

---

## 13. Decisions needed from Eliran

| # | Decision | Recommendation |
|---|---|---|
| 1 | App name on the store | "Cuanto Socials" (check availability in Phase 0) |
| 2 | Payments in v1 | None; web subscription unlocks; US-only external link in 1.1 |
| 3 | Channel connect in v1 or "connect on web" | In the app (stronger 4.2 case, better experience) |
| 4 | iPad layout in v1 | No, iPhone only |
| 5 | Account deletion + subscription | Cancel at period end, delete data right away |
| 6 | Staging stack on deb (RAM cost) vs a test org on prod | Staging on deb, memory-capped |
| 7 | App Store category | Productivity |
| 8 | APNs key | Reuse the team's existing ShulMaker `.p8` if it's there; otherwise mint one (portal only, no API) |
| 9 | Beta testers | The current ~6 web users via TestFlight External |

---

## 14. Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| 4.2 rejection ("website in an app") | Low with this plan | High | Share extension, widgets, push, intents in 1.0; review notes list native features |
| Upstream Postiz merge breaks internal services the facade calls | Medium | Medium | Facade in fork-owned files, compile-time breakage, nightly contract test on staging, merge rehearsal in Phase 5 |
| LinkedIn or X API changes or restrictions | Medium | High | The backend owns the provider logic; the app is provider-neutral and driven by `/channels` metadata; the pending LinkedIn Advertising API approval only affects Pages scopes |
| deb or Funnel outage → app looks broken | Medium | High | Clear offline and "service unavailable" states, the outbox keeps drafts, existing uptime monitoring + fleet-watchdog; consider a CF Tunnel for `api.` as a second path |
| AGPL / App Store terms conflict claim | Low | High | No AGPL code in the app binary; our own Swift client; source link for the server; optional legal review |
| Reviewer can't test posting (no LinkedIn account) | High if not prepared | Medium | Demo account with a pre-connected test channel + a video in the review notes if needed |
| Video uploads fail on cellular or in the background | Medium | Medium | Multipart presigned R2 upload, background URLSession, resumable parts |
| Account deletion leaves queued posts publishing | Low | High | Cancel Temporal workflows in the deletion transaction + a test |
| Push token and environment mix-ups (sandbox vs production) | Medium | Low | Store the environment per device; send to the matching APNs host; staging builds use sandbox |
| Mini simulator contention with other iOS work | Medium | Low | The sim lock, the `--light` flag, scheduling heavy UI runs off-hours |
| Pricing rules change (3.1.x) | Medium | Medium | No purchases in v1; re-check before each submission |
| deb RAM pressure from the staging stack | Medium | Medium | Memory caps in compose, `deb-governor`, stop staging when idle |

### Pre-drafted rejection responses
- **4.2:** list native features with a short screen recording link.
- **2.1 can't sign in or post:** re-check demo credentials; offer a call; attach a video of the connect flow.
- **5.1.1(v):** point to Settings → Delete account (with screenshots).
- **3.1.1:** confirm there are no purchase prompts; the web subscription is multiplatform access under 3.1.3(b).
- **5.1.2(i):** show the AI consent sheet screenshots.

---

## 15. Agent and work routing (how this gets built)

- **planner** (fable): refines each phase into milestone specs with exact files and acceptance tests before the phase starts.
- **implementer** (sonnet): one milestone per run, e.g. "4.1 mobile auth endpoints", "Composer media tray". Escalate to fable after 2 failures. Backend and iOS milestones in the same phase run in parallel using **worktrees** (separate trees: `apps/backend/**` vs `ios/**`).
- **typescript-reviewer** + **security-reviewer**: gate every backend PR touching mobile auth, deletion, push or media.
- **code-reviewer**: gates iOS PRs; **loop-verifier** before merging.
- **e2e-runner**: owns the sim E2E suite and the design gate runs.
- Branching: this repo deploys `main` to Vercel. iOS work goes on feature branches → PR → `main`. Backend mobile changes deploy through `postiz-stack.sh deploy` after merging. Keep backend deploys separate from risky upstream catch-ups (never both in one deploy).
- Commits: `feat(ios): …`, `feat(mobile-api): …`, one logical unit each.

---

## 16. Rough cost

| Item | Cost |
|---|---|
| Apple Developer Program | already paid (team 8AWCD3T4B5) |
| APNs | free |
| Staging stack on deb | $0 cash; ~1.5–2 GB RAM while running |
| App Store commission | $0 in v1 (no IAP) |
| AI usage from mobile copilot | same pool and limits as web; watch the OpenRouter credit (keep hourly limits, maybe a lower mobile default) |
| Optional legal review (AGPL/App Store) | ~$300–800 one-off, if wanted |
| Developer time | ~10–12 weeks part-time, per §12 |

---

## 17. Appendix — current backend facts this plan relies on (checked 2026-09-16)

- Web sign-in: JWT in the `auth` cookie; the middleware also accepts an `auth` header; org from the `showorg` cookie or header (`apps/backend/src/services/auth/auth.middleware.ts`).
- User login providers: Google, GitHub, **Apple**, Farcaster, Wallet, generic OAuth (`apps/backend/src/services/auth/providers/`).
- `GET /auth/oauth-mobile-callback` exists and redirects to `MOBILE_APP_SCHEME` (unset → `postiz://auth/callback`; **must be set**).
- Public API `/public/v1/*` with a per-org API key or `pos_` OAuth tokens (`oauth.controller.ts`, `public.auth.middleware.ts`).
- No account deletion endpoint exists → must build.
- No push (APNs/FCM) code exists; an in-app `Notifications` model does.
- No websocket or SSE events → push + polling.
- Stripe is on; limits come from `permissions.service.ts` and are active only when `STRIPE_PUBLISHABLE_KEY` is set.
- Only 2 providers boot (`ENABLED_INTEGRATIONS`), with a Redis live toggle.
- CORS is browser-only and doesn't affect a native app.
- Repo license: AGPL-3.0; branding through `BRAND_NAME` / `brand.ts`.
- iOS tooling: CuantoKit (iOS 18+, no auth or push module yet), ios-suite (ship/submit only dry-run-tested), ShulMaker APNs stack as reference, bundle prefix `com.cuantolabs`, ASC key `fleet-ci`.
