# @cuantolabs/mail

A Resend-shaped `send()` client over the Plunk v1 API, plus `track()`/`contacts.*`
marketing helpers and a Payload CMS v3 email adapter. Plain ESM + JSDoc, no
TypeScript build step, no required dependencies.

## Install

There is no public/GitHub repo for this package. Vendor it into your project
instead, from the mail-platform repo root:

```
scripts/mail-vendor.sh <project-dir>
```

This copies `dist/`, `package.json`, `LICENSE`, and `README.md` into
`<project-dir>/vendor/cuanto-mail/`, points `dependencies['@cuantolabs/mail']`
at `file:./vendor/cuanto-mail` in `<project-dir>/package.json`, then reminds
you to run your project's package manager install. Pass `--dry-run` to see
the actions without writing anything.

## Configuration

All config can be passed to `createMail({...})` or left to fall back to env vars:

| Env var | Purpose |
|---|---|
| `MAIL_API_URL` | API base URL. Defaults to `https://mail-api.cuantolabs.com`. |
| `MAIL_API_KEY` | Bearer token sent as `Authorization: Bearer <key>`. |
| `MAIL_FROM` | Default `from` address used when `send()` omits one. |
| `MAIL_DEV` | Dev-mode override: `off` (default), `log` (print instead of send), or `redirect:<address>` (send everything to one inbox). |

## Swapping in from Resend

```js
// import { Resend } from "resend";
// const resend = new Resend(process.env.RESEND_API_KEY);
// await resend.emails.send({ from, to, subject, html });
import mail from "@cuantolabs/mail";
await mail({ from, to, subject, html });
```

`send()` accepts the same shape Resend does (`from`, `to`, `subject`, `html`,
`text`, `react`, `replyTo`, `cc`, `bcc`, `tags`, `headers`) and returns
`{ data, error }` instead of throwing.

## Payload CMS adapter

```js
import { payloadAdapter } from "@cuantolabs/mail/payload";

export default buildConfig({
  email: payloadAdapter({
    defaultFromAddress: "noreply@example.com",
    defaultFromName: "Example",
  }),
  // ...
});
```

`sendEmail()` maps Payload's Nodemailer-style message onto `send()` and throws
a `MailError` on failure (Payload's `EmailAdapter` contract expects a throw,
not a returned error).

## track() and contacts.*

```js
import { track, contacts } from "@cuantolabs/mail";

await track({ event: "signup", email: "person@example.com", data: { plan: "pro" } });

await contacts.create({ email: "person@example.com", subscribed: true });
await contacts.get(id);
await contacts.update(id, { data: { plan: "team" } });
await contacts.remove(id);
await contacts.list({ status: "subscribed", limit: 50 });
await contacts.subscribe("person@example.com");
await contacts.unsubscribe("person@example.com");
```

`contacts.create/get/update/remove/list` mirror Plunk's dashboard `/contacts`
routes 1:1 and require a dashboard-session-backed key; `contacts.subscribe`/
`unsubscribe` instead go through `track()`, which works with a plain project
API key.

## Errors

Every failure is a typed `MailError` subclass with `.code`, `.statusCode`, and
`.retryable`:

| Class | When | Retried automatically |
|---|---|---|
| `MailValidationError` | Missing required field, or a 4xx that isn't auth/rate-limit | No |
| `MailAuthError` | 401/403 | No |
| `MailRateLimitError` | 429 (carries `.retryAfterMs`) | Yes |
| `MailServerError` | 5xx | Yes |
| `MailNetworkError` | Request failed before a response arrived | Yes |

`send()`/`track()`/`contacts.*` never throw: they return `{ data: null, error }`.
The Payload adapter is the one exception: it throws, per Payload's contract.
