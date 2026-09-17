# iOS Submission Log — Cuanto Socials

Tracks build state vs. the external (Eliran-only) work still needed to ship. Spec: `docs/IOS-APP-PLAN.md`
(17 sections, authoritative). Vision/scope: `.claude/autopilot/VISION.md`.

## Build state (as of 2026-09-17)

- **Repo / branch:** `cuanto-socials-wt-ios` worktree, branch `feat/ios-app`, cut from `origin/main` (e4e3b1fc).
  Local commits only — no push, no external writes made by autopilot.
- **Code-complete locally, per VISION.md Definition of Done:**
  - Backend `/mobile/v1` facade (new files only): auth (email login/register, Apple native identity token,
    Google PKCE exchange, refresh rotation 15m/60d, logout, device list/revoke), `MobileAuthMiddleware`,
    `me`, `config`, `channels`, `posts` CRUD + reschedule with Idempotency-Key, media presigned upload,
    `DELETE /mobile/v1/account` cascade + Temporal workflow cancellation, `PushDevice` register/unregister
    + `PushService` (APNs HTTP/2 client, fake-transport unit tests), copilot endpoints gated on server-side
    AI consent, channel-connect start URL + `/m/connected` frontend page, `apple-app-site-association`
    served from frontend `public/.well-known/`. Prisma migration(s) added. `docs/MOBILE-API.md` documents
    every route.
  - iOS app (Xcode 27.0 project via `xcodegen`, `ios/Project.yml`): App + ShareExtension + Widgets + Intents
    targets. Onboarding, sign-in (Apple/Google/email) + org switcher, channels list + connect/reconnect,
    composer (per-channel overrides, char/media limits, photo picker, upload queue, schedule sheet, drafts
    in SwiftData + outbox sync), calendar (agenda/week/month, reschedule), post detail, notifications feed +
    push registration/categories/deep links, copilot with consent sheet, settings (account, devices,
    notification prefs, delete account, legal/open-source notices, analytics opt-out), share extension,
    widgets (home + lock), App Intents, `PrivacyInfo.xcprivacy` per target, accessibility labels, Dynamic
    Type. All networking via `SocialsAPI` protocol against `LiveSocialsAPI` → `/mobile/v1` (no placeholder
    data outside tests/XCUITest launch arg).
  - One XCUITest sign-in → channels → compose → schedule flow against a mock API (launch arg) passes on sim.
- **Gates (must both be green before any external step below runs):**
  - Backend: `scripts/mobile-gate.sh` — prisma validate; `apps/backend` `tsc --noEmit` error count ≤ baseline
    7 (pre-existing, listed in `.claude/autopilot/VISION.md`), zero errors under any `mobile` path; mobile
    jest specs pass.
  - iOS: `ios/scripts/gate.sh` — `xcodegen generate` + `xcodebuild build` of all targets for iOS Simulator
    with `CODE_SIGNING_ALLOWED=NO`, Swift Testing unit tests on one simulator (repo flock + machine-wide sim
    lock, mirrors `ios-suite`).
  - Combined run-gates step (must exit 0 before merge/submission work starts):
    `scripts/mobile-gate.sh && ios/scripts/gate.sh`
- **Not done by autopilot (explicitly out of scope, VISION.md "External writes: NOT granted"):** no git push,
  no deploy (Vercel/deb), no App Store Connect / TestFlight actions, no APNs sends, no emails, no device
  testing, no staging stack stand-up.

## External steps pending for Eliran

Ordered by dependency. Nothing below has been started by autopilot; every row is `pending`.

| # | Step | Depends on | Status |
|---|---|---|---|
| 1 | ASC app record — reserve name "Cuanto Socials", create the app record (bundle ID `com.cuantolabs.socials`, category Productivity, age rating 4+, pricing free) | — | pending |
| 2 | Bundle IDs + App Group + provisioning profiles via `ios-sign` — register `com.cuantolabs.socials` (+ `.share`, `.widgets`, `.intents`), App Group `group.com.cuantolabs.socials`, Keychain group `8AWCD3T4B5.com.cuantolabs.socials.shared`; mint a profile per target (ASC API key `fleet-ci`); unlock the login keychain before headless `codesign` | 1 | pending |
| 3 | APNs `.p8` key — reuse the team's ShulMaker key if still valid, or mint a new one in the Apple Developer portal (no API for this); store in vault | 1 | pending |
| 4 | Backend deploy of `/mobile/v1` + Prisma migration — run the migration, deploy the fork (`postiz-stack.sh deploy`), keep separate from any upstream Postiz catch-up deploy | run-gates green | pending |
| 5 | Staging stack on deb — stand up `pz-staging` (memory-capped), staging DNS name, test channel accounts in the vault | 4 | pending |
| 6 | TestFlight Internal build — archive/upload via `ios-preflight` → `ios-ship` from a clean `main` checkout only (never a feature branch) | 2, 3, 4 | pending |
| 7 | Screenshots — real-device captures, 6.9" + 6.5" sizes as ASC requires | 6 | pending |
| 8 | Review notes + reviewer demo account — pre-connected test channel on production, sample scheduled posts, notes explaining the OAuth connect flow | 4, 5 | pending |
| 9 | Privacy nutrition labels + `PrivacyInfo.xcprivacy` review in ASC, export compliance flag (`ITSAppUsesNonExemptEncryption = NO`) | 1 | pending |
| 10 | Availability — after approval, set territories via `appAvailabilityV2` and confirm with a storefront lookup ("approved" ≠ live in any country) | submit + approval | pending |

## Notes

- Re-check the current App Review Guidelines text (3.1, 4.2, 4.8, 5.1, 5.2) in the week before submitting
  and log the date checked here.
- Beta testers: the current ~6 web users via TestFlight External, once TestFlight Internal (row 6) is green.
- Full phased roadmap and Apple-compliance matrix: `docs/IOS-APP-PLAN.md` §§ 2, 11–14.

## FINAL GATE — 2026-09-17 (EST)

Local code-complete gate on `feat/ios-app`, all green on one simulator (iPhone 17 Pro Max):

- `scripts/mobile-gate.sh` — prisma validate, backend tsc (baseline only, zero `mobile` errors), mobile jest specs.
- `ios/scripts/gate.sh` — xcodegen, build of App/ShareExtension/Widgets/Intents, SocialsCore + app unit tests,
  `CuantoSocialsUITests` (sign-in → channels → compose → schedule against `-uiTestStub`), a11y lint.
- No placeholder/sample data in shipping sources; stub API referenced only from `AppEnvironment.swift` +
  `Testing/UITestFixtures.swift`.
- Intentionally not done (Decision 8): T078–T083 AI usage tables, superseded by web CheckPolicies/Credits.

Everything in the table above remains external and pending.
