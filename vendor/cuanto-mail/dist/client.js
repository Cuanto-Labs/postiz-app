/**
 * @cuantolabs/mail client, a Resend-shaped send() over the Plunk v1 API.
 * Plain ESM + JSDoc, no TypeScript build step.
 */

import {
  MailError,
  MailValidationError,
  MailRateLimitError,
  MailNetworkError,
  fromResponse,
} from "./errors.js";
import { parseDevMode, devLogSend } from "./dev.js";
import { createMarketing } from "./marketing.js";

const ADDRESS_WITH_NAME = /^\s*"?([^"<]*?)"?\s*<([^>]+)>\s*$/;

const DEFAULT_API_URL = "https://mail-api.cuantolabs.com";
const MAX_RETRY_AFTER_MS = 30_000;
const BASE_BACKOFF_MS = 250;
const MAX_ATTACHMENTS = 10;

/**
 * @param {number} ms
 * @returns {Promise<void>}
 */
function defaultSleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Exponential backoff with full jitter.
 * @param {number} attempt zero-based retry attempt index
 */
function backoffMs(attempt) {
  const exp = BASE_BACKOFF_MS * 2 ** attempt;
  return exp + Math.random() * BASE_BACKOFF_MS;
}

/**
 * Delay to honor for a 429, capped at MAX_RETRY_AFTER_MS.
 * @param {Response} res
 * @param {MailRateLimitError} err
 */
function retryAfterMs(res, err) {
  const header = typeof res?.headers?.get === "function" ? res.headers.get("Retry-After") : undefined;
  const headerSeconds = header !== undefined && header !== null ? Number(header) : NaN;
  let seconds = headerSeconds;
  if (!Number.isFinite(seconds)) {
    seconds = err?.retryAfterMs !== undefined ? err.retryAfterMs / 1000 : undefined;
  }
  const ms = seconds !== undefined && Number.isFinite(seconds) ? seconds * 1000 : BASE_BACKOFF_MS;
  return Math.min(ms, MAX_RETRY_AFTER_MS);
}

/**
 * Core HTTP request used by send(). Exported so callers/tests can drive it
 * directly. Throws a typed MailError subclass on any non-2xx response or
 * transport failure once retries are exhausted; never returns a non-ok
 * response.
 *
 * @param {object} params
 * @param {string} params.apiUrl
 * @param {string} params.apiKey
 * @param {string} [params.path] request path, e.g. '/v1/send' or '/contacts/:id'
 * @param {string} [params.method] HTTP method, defaults to 'POST'
 * @param {object} [params.payload] JSON body; omitted entirely when undefined (e.g. GET/DELETE)
 * @param {typeof fetch} params.fetchImpl
 * @param {number} params.retries
 * @param {(ms:number)=>Promise<void>} params.sleepImpl
 * @returns {Promise<any>} parsed JSON response body
 */
export async function request({ apiUrl, apiKey, path = "/v1/send", method = "POST", payload, fetchImpl, retries, sleepImpl }) {
  let attempt = 0;
  for (;;) {
    let res;
    try {
      res = await fetchImpl(`${apiUrl}${path}`, {
        method,
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        ...(payload !== undefined ? { body: JSON.stringify(payload) } : {}),
      });
    } catch (cause) {
      if (attempt < retries) {
        await sleepImpl(backoffMs(attempt));
        attempt += 1;
        continue;
      }
      throw new MailNetworkError("mail request failed before a response was received", { cause });
    }

    let body;
    try {
      body = await res.json();
    } catch {
      body = undefined;
    }

    if (res.ok) {
      return body;
    }

    const errBody = body && typeof body === "object" && "error" in body ? body.error : body;
    const err = fromResponse(res.status, errBody);

    if (err.retryable && attempt < retries) {
      const delay = err instanceof MailRateLimitError ? retryAfterMs(res, err) : backoffMs(attempt);
      await sleepImpl(delay);
      attempt += 1;
      continue;
    }

    throw err;
  }
}

/**
 * @param {string} field
 * @returns {{data: null, error: MailValidationError}}
 */
function validationError(field) {
  return { data: null, error: new MailValidationError(`send() requires ${field}`) };
}

/**
 * @param {object} [config]
 * @param {string} [config.apiKey]
 * @param {string} [config.apiUrl]
 * @param {string} [config.from]
 * @param {typeof fetch} [config.fetch]
 * @param {number} [config.retries]
 * @param {(ms:number)=>Promise<void>} [config.sleep]
 * @param {string} [config.dev] MAIL_DEV override: 'off'|'log'|'redirect:<addr>'
 */
export function createMail(config = {}) {
  const apiKey = config.apiKey ?? process.env.MAIL_API_KEY;
  const apiUrl = config.apiUrl ?? process.env.MAIL_API_URL ?? DEFAULT_API_URL;
  const defaultFrom = config.from ?? process.env.MAIL_FROM;
  const fetchImpl = config.fetch ?? globalThis.fetch;
  const retries = config.retries ?? 2;
  const sleepImpl = config.sleep ?? defaultSleep;
  const devMode = parseDevMode(config.dev ?? process.env.MAIL_DEV);

  /**
   * @param {object} message
   * @param {string} [message.from]
   * @param {string|object|Array} message.to
   * @param {string} message.subject
   * @param {string} [message.html]
   * @param {string} [message.text]
   * @param {unknown} [message.react]
   * @param {string} [message.replyTo]
   * @param {string|string[]} [message.cc]
   * @param {string|string[]} [message.bcc]
   * @param {string|string[]} [message.tags]
   * @param {Record<string,string>} [message.headers]
   * @param {Array<{filename:string, content:string|Uint8Array, contentType?:string}>} [message.attachments]
   *   string content is taken as already base64; Buffer/Uint8Array is encoded.
   * @returns {Promise<{data: {id:string}|null, error: MailError|null}>}
   */
  async function send(message = {}) {
    const { from = defaultFrom, to, subject, html, text, react, replyTo, cc, bcc, tags, headers, attachments } = message;

    if (!to) return validationError("a to address");
    if (!subject) return validationError("a subject");
    if (!from) return validationError("a from address");

    let body = html ?? text ?? undefined;
    if (body === undefined && react !== undefined && react !== null) {
      let renderModule;
      try {
        renderModule = await import("@react-email/render");
      } catch (cause) {
        return {
          data: null,
          error: new MailValidationError(
            "@react-email/render is required to render a react email template",
            { cause },
          ),
        };
      }
      try {
        body = await renderModule.render(react);
      } catch (cause) {
        return {
          data: null,
          error: new MailValidationError("failed to render react email template", { cause }),
        };
      }
    }
    if (!body) return validationError("html, text, or react content");

    let plunkAttachments;
    if (attachments !== undefined && attachments !== null) {
      if (!Array.isArray(attachments)) return validationError("attachments as an array");
      if (attachments.length > MAX_ATTACHMENTS) {
        return validationError(`at most ${MAX_ATTACHMENTS} attachments`);
      }
      plunkAttachments = [];
      for (const a of attachments) {
        if (!a || !a.filename || a.content === undefined || a.content === null) {
          return validationError("attachments with filename and content");
        }
        const content =
          typeof a.content === "string" ? a.content : Buffer.from(a.content).toString("base64");
        plunkAttachments.push({
          filename: a.filename,
          content,
          contentType: a.contentType ?? "application/octet-stream",
        });
      }
      if (plunkAttachments.length === 0) plunkAttachments = undefined;
    }

    if (devMode.mode === "log") {
      return devLogSend({ from, to, subject, html, text });
    }

    let effectiveTo = to;
    let effectiveSubject = subject;
    let effectiveCc = cc;
    let effectiveBcc = bcc;
    if (devMode.mode === "redirect") {
      effectiveTo = [devMode.to];
      effectiveSubject = `[dev → ${JSON.stringify(to)}] ${subject}`;
      effectiveCc = undefined;
      effectiveBcc = undefined;
    }

    const mergedHeaders = { ...(headers ?? {}) };
    if (effectiveCc !== undefined) mergedHeaders.Cc = effectiveCc;
    if (effectiveBcc !== undefined) mergedHeaders.Bcc = effectiveBcc;
    if (tags !== undefined) mergedHeaders["X-Tags"] = Array.isArray(tags) ? tags.join(",") : tags;

    // Plunk wants a bare address plus a separate `name`; Resend accepts
    // "Name <addr>", which every migrated app passes.
    const fromMatch = ADDRESS_WITH_NAME.exec(from);
    const fromAddress = fromMatch ? fromMatch[2].trim() : from;
    const fromName = fromMatch ? fromMatch[1].trim() : "";
    const bareAddress = (addr) => {
      const m = typeof addr === "string" ? ADDRESS_WITH_NAME.exec(addr) : null;
      return m ? m[2].trim() : addr;
    };

    const payload = {
      to: Array.isArray(effectiveTo) ? effectiveTo.map(bareAddress) : bareAddress(effectiveTo),
      subject: effectiveSubject,
      body,
      from: fromAddress,
      ...(fromName ? { name: fromName } : {}),
      ...(replyTo !== undefined ? { reply: replyTo } : {}),
      ...(Object.keys(mergedHeaders).length > 0 ? { headers: mergedHeaders } : {}),
      ...(plunkAttachments ? { attachments: plunkAttachments } : {}),
    };

    try {
      const responseBody = await request({ apiUrl, apiKey, payload, fetchImpl, retries, sleepImpl });
      const id = responseBody?.data?.emails?.[0]?.email ?? responseBody?.data?.id ?? null;
      return { data: id ? { id } : null, error: null };
    } catch (error) {
      if (error instanceof MailError) {
        return { data: null, error };
      }
      return { data: null, error: new MailError(error?.message ?? "mail request failed", { cause: error }) };
    }
  }

  const { track, contacts } = createMarketing({ apiUrl, apiKey, fetchImpl, retries, sleepImpl });

  return { send, track, contacts };
}
