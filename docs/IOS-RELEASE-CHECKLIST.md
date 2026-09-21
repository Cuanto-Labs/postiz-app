# iOS Release Checklist — Cuanto Socials

Working checklist for taking the code-complete `feat/ios-app` branch to a live App Store release. Pair with
`docs/IOS-SUBMISSION-LOG.md` (status table) and `docs/IOS-APP-PLAN.md` (spec, authoritative).

## 0. Run the gates first

- [ ] `scripts/mobile-gate.sh && ios/scripts/gate.sh` exits 0 on the tree you're about to ship. Do not start
      any step below on a red gate. `ios/scripts/gate.sh` runs `xcodegen generate` + `xcodebuild build` for
      all targets (App, ShareExtension, Widgets, Intents) with signing disabled, plus Swift Testing on one
      simulator — takes a repo flock + the machine-wide sim lock, never boot a second simulator on Mini.

## 1. Identifiers and signing

- [ ] Reserve app name "Cuanto Socials" in App Store Connect.
- [ ] Register bundle IDs: `com.cuantolabs.socials` (app), `com.cuantolabs.socials.share`,
      `com.cuantolabs.socials.widgets`, `com.cuantolabs.socials.intents` — see `ios/Project.yml`
      `bundleIdPrefix: com.cuantolabs` and per-target `PRODUCT_BUNDLE_IDENTIFIER`.
- [ ] Register App Group `group.com.cuantolabs.socials` and Keychain group
      `8AWCD3T4B5.com.cuantolabs.socials.shared` (team `8AWCD3T4B5`).
- [ ] Mint provisioning profiles per target via `ios-sign` (ASC API key `fleet-ci`). Unlock the login
      keychain first — a locked keychain fails headless `codesign` with `errSecInternalComponent`.

## 2. Backend env vars (Apple sign-in + AASA)

Two distinct Apple-bundle-ID env vars — do not conflate them:

- [ ] `APPLE_APP_BUNDLE_ID` — already read by `apps/backend/src/services/auth/providers/apple.provider.ts`
      (native Sign in with Apple identity-token verification). Native `ASAuthorizationAppleIDCredential`
      tokens carry the app's bundle ID as `aud`, not the web Services ID (`APPLE_CLIENT_ID`), so this must be
      set to `com.cuantolabs.socials` in the backend env (deploy + staging) or native Apple sign-in on the
      app fails verification.
- [ ] `APPLE_BUNDLE_ID` — set for the `apple-app-site-association` (AASA) generation path
      (`public/.well-known/apple-app-site-association`, frontend) and any Universal Links / associated-domains
      wiring for `socials.cuantolabs.com`. The AASA `appID` entry is `<team>.<bundle>`
      (`8AWCD3T4B5.com.cuantolabs.socials`) — confirm which of `APPLE_APP_BUNDLE_ID` / `APPLE_BUNDLE_ID` the
      AASA route reads at deploy time (not yet wired to an env var in this branch as of 2026-09-17 — verify
      before deploy, add if missing) and keep both vars set to the same value to avoid drift.

## 3. Push (APNs)

- [ ] Mint or reuse the APNs `.p8` key — check first whether the team's existing ShulMaker `.p8` can be
      reused; otherwise mint a new one in the Apple Developer portal (no API for key creation).
- [ ] Store the key + Key ID + Team ID in the vault; wire into backend `PushService` env.
- [ ] Confirm sandbox vs production APNs host is selected per build (staging → sandbox, TestFlight/prod →
      production); store the environment per registered device (`PushDevice`).

## 4. Backend deploy

- [ ] Run the Prisma migration for the mobile models (`MobileSession`, `PushDevice`, etc.).
- [ ] Deploy `/mobile/v1` via `postiz-stack.sh deploy` — keep separate from any unrelated upstream Postiz
      catch-up deploy (never both in one deploy).
- [ ] Stand up `pz-staging` on deb (memory-capped), staging DNS, test channel accounts in the vault.
- [ ] Smoke test: sign in, list channels, create/reschedule/delete a post, delete a throwaway account —
      against staging.

## 5. TestFlight

- [ ] Archive from a **clean `main` checkout only** (never a feature branch — TestFlight Internal auto-installs
      regressions on Eliran's phone).
- [ ] `ios-preflight` → `ios-ship`.
- [ ] TestFlight Internal build signs in and shows channels on Eliran's phone.
- [ ] TestFlight External with the current ~6 web users for ≥ 7 days; fix feedback before submitting.
- [ ] Log each TestFlight build number + date in `docs/IOS-SUBMISSION-LOG.md`.

## 6. Store listing

- [ ] Screenshots — real device, 6.9" + 6.5" sizes as ASC requires (no platform logos, no "LinkedIn app"
      wording).
- [ ] App preview video (optional), description, keywords, support URL, marketing URL.
- [ ] Age rating 4+, pricing free, category Productivity.
- [ ] Reviewer demo account on production with a pre-connected test channel and sample scheduled posts.
- [ ] Review notes explaining the OAuth connect flow and that posting goes to the account's own channels.

## 7. Privacy

- [ ] `PrivacyInfo.xcprivacy` present for App target and every extension (Share, Widgets, Intents);
      required-reason APIs (UserDefaults, file timestamps) declared.
- [ ] Nutrition labels in ASC: contact info, user content, identifiers — all "linked to user, not used for
      tracking". No ATT prompt (no tracking).
- [ ] Export compliance: `ITSAppUsesNonExemptEncryption = NO` (standard HTTPS only).
- [ ] Privacy policy / terms pages on socials.cuantolabs.com updated for mobile (push, device IDs, AI
      sharing, deletion).

## 8. Re-check guidelines before submitting

- [ ] Re-read current App Review Guidelines 3.1, 4.2, 4.8, 5.1, 5.2 the week of submission; log the date
      checked in `docs/IOS-SUBMISSION-LOG.md`.
- [ ] Confirm no purchase UI/links outside the US storefront (3.1.1 / 3.1.3(b)).
- [ ] Confirm Settings → Delete account flow still works end to end (5.1.1(v)).

## 9. Submit and launch

- [ ] Submit (manual release).
- [ ] Answer any rejection within 24h (pre-drafted responses: `docs/IOS-APP-PLAN.md` §14).
- [ ] After approval — **do not assume live**: set territories via `appAvailabilityV2` and confirm with a
      storefront lookup. "Approved" ≠ available in any country (lesson from an earlier app).
- [ ] Launch posts via Cuanto Socials itself (LinkedIn) + website "Get the iPhone app" smart app banner on
      socials.cuantolabs.com.
- [ ] Watch crash reports, OnyxMetric funnels, and backend `/mobile/v1` logs for 72h post-launch.
