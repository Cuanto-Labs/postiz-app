# Cuanto Socials — Future Features

## Auto-Comment / Auto-Reply to inbound comments

**Status:** Planned. Blocked on LinkedIn **Community Management API** approval (for clean server-side comment reads on Company Pages). Write path already proven; see below.

### Summary
Read inbound comments on a published post, AI-draft a personalized reply per commenter (anti-slop, on-brand voice), then send via API — review-gated by default, optional auto-send with rules. Paced to respect rate limits and avoid account anti-spam blocks.

### Read access — the gating constraint (write is solved)
| Account | Read path | Notes |
|---|---|---|
| LinkedIn personal | Postiz Chrome extension harvests from the user's logged-in session | `r_member_social` is a **closed** permission (LinkedIn not accepting requests) — no server-side API read. Extension runs in the user's own browser, no server scrape. |
| LinkedIn Company Page | Community Management API (`r_organization_social_feed`) | Clean server-side read. **Needs LinkedIn app approval — what we're waiting on.** |
| Instagram / Facebook | Graph API native (`instagram_manage_comments`, already granted) | Easiest. Read + reply both server-side. Good first non-LinkedIn target. |

### Write path — PROVEN (2026-06-28)
Works today with the existing member token (`w_member_social`), no extra approval:
```
POST https://api.linkedin.com/rest/socialActions/{activityUrn}/comments
Headers: Authorization: Bearer <token>; X-Restli-Protocol-Version: 2.0.0; LinkedIn-Version: 202306; Content-Type: application/json
Body (reply): {"actor":"urn:li:person:<id>","object":"{activityUrn}","parentComment":"urn:li:comment:({activityUrn},<parentId>)","message":{"text":"..."}}
-> 201; x-restli-id = new comment id. DELETE .../comments/{id}?actor=<person> -> 204.
```
- Target MUST be the `urn:li:activity:` URN (not `urn:li:share:`).
- Omit `parentComment` for a top-level comment.
- `202306`/`/v2` accept `w_member_social`; the `202606` path requires the closed `w_member_social_feed` (403).
- Rate: short-term per-minute throttle (`429 "Comment create throttled"`); ~150 creates/member/day. 6s spacing tested clean for 10 in a row.

### Architecture (maps to monorepo)
- **Provider interface** (`libraries/.../social.integrations.interface.ts`): add `getComments?()` + `replyToComment?()`.
- **LinkedIn provider**: `replyToComment` = the proven call; `getComments` = CM API (org) / throw "use extension" (personal).
- **Extension** (`apps/extension`): handler to harvest comment `componentkey` URNs + author + text from the live DOM, POST to backend.
- **DB (Prisma)**: `InboundComment {id, integrationId, postId, externalCommentUrn, author, text, status, createdAt}`, `CommentReply {id, inboundCommentId, draftText, status: draft|approved|sent|failed, sentCommentUrn, sentAt}`. (Add GRANT migration for new tables.)
- **Backend** (`apps/backend`, Controller→Manager→Service→Repository): list comments, generate drafts, edit/approve, send, settings.
- **Orchestrator** (`apps/orchestrator`, Temporal): `harvestComments`, `generateReplies` (LLM), `sendReplies` (token-bucket per account, 6s+ spacing, 429 backoff, daily cap).
- **AI**: reuse OpenAI integration; prompt = per-account persona + anti-slop ruleset (no em-dashes, no "Great question"/buzzwords, vary openings, concede valid points) + few-shot from the user's real replies; validator rejects slop pre-queue.
- **Frontend**: new "Engagement" page — comment inbox, editable draft cards, approve/send, settings (tone, review vs auto-send, pacing, daily cap, author blocklist).

### Safety defaults
- Human-in-loop (review before send) by default; auto-send opt-in per account.
- Pacing + per-account daily ceiling baked in (anti action-block).
- ToS reality surfaced in UI for personal-account extension mode.

### Phasing
- **Phase 0** — done: write proven, read-via-session proven (manual run hit 11 live replies on a 122k-impression post).
- **Phase 1 (MVP)** — LinkedIn personal via extension harvest + manual-trigger drafts + review UI + paced send, single account.
- **Phase 2** — Temporal auto-poll, auto-send + rules, multi-account, analytics.
- **Phase 3** — Company Pages via CM API (after approval), IG/FB native, nested-reply threading, sentiment routing.

### Effort
Phase 1 MVP ≈ provider methods + 2 DB tables + 4 routes + extension handler + 1 Temporal workflow + 1 frontend page (~3–5 focused build sessions).
