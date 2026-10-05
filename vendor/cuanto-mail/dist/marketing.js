/**
 * @cuantolabs/mail marketing helpers: track() and contacts.* over the Plunk v1 API.
 * Plain ESM + JSDoc, no TypeScript build step.
 *
 * contacts.create/get/update/remove/list mirror Plunk's dashboard `/contacts` routes
 * 1:1 (docs/research/plunk-upstream.md contacts_routes). Those routes require a
 * dashboard session cookie upstream (requireAuth), not a project API key, so calling
 * them with an api-key-only client will get MailAuthError from the real server,
 * that mirrors upstream, it is not a bug here. contacts.subscribe/unsubscribe instead
 * go through track() (track_payload.subscribed), the one subscription-state change
 * that IS reachable with a public/secret key.
 */

import { MailError, MailValidationError } from "./errors.js";
import { request } from "./client.js";

/**
 * @param {string} field
 * @returns {{data: null, error: MailValidationError}}
 */
function validationError(field) {
  return { data: null, error: new MailValidationError(`this call requires ${field}`) };
}

/**
 * @param {unknown} error
 * @returns {{data: null, error: MailError}}
 */
function toResult(error) {
  if (error instanceof MailError) {
    return { data: null, error };
  }
  return { data: null, error: new MailError(error?.message ?? "mail request failed", { cause: error }) };
}

/**
 * @param {object} config
 * @param {string} config.apiUrl
 * @param {string} config.apiKey
 * @param {typeof fetch} config.fetchImpl
 * @param {number} config.retries
 * @param {(ms:number)=>Promise<void>} config.sleepImpl
 */
export function createMarketing({ apiUrl, apiKey, fetchImpl, retries, sleepImpl }) {
  /**
   * @param {object} params
   * @param {string} params.method
   * @param {string} params.path
   * @param {object} [params.payload]
   * @returns {Promise<{data:any, error:MailError|null}>}
   */
  async function run({ method, path, payload }) {
    try {
      const body = await request({ apiUrl, apiKey, method, path, payload, fetchImpl, retries, sleepImpl });
      return { data: body ?? null, error: null };
    } catch (error) {
      return toResult(error);
    }
  }

  /**
   * @param {object} params
   * @param {string} params.event
   * @param {string} params.email
   * @param {boolean} [params.subscribed]
   * @param {object} [params.data]
   * @returns {Promise<{data:any, error:MailError|null}>}
   */
  async function track({ event, email, subscribed, data } = {}) {
    if (!event) return validationError("an event name");
    if (!email) return validationError("an email");
    const payload = {
      event,
      email,
      ...(subscribed !== undefined ? { subscribed } : {}),
      ...(data !== undefined ? { data } : {}),
    };
    return run({ method: "POST", path: "/v1/track", payload });
  }

  const contacts = {
    /**
     * @param {object} params
     * @param {string} params.email
     * @param {object} [params.data]
     * @param {boolean} [params.subscribed]
     */
    create({ email, data, subscribed } = {}) {
      if (!email) return Promise.resolve(validationError("an email"));
      const payload = { email, ...(data !== undefined ? { data } : {}), ...(subscribed !== undefined ? { subscribed } : {}) };
      return run({ method: "POST", path: "/contacts", payload });
    },
    /**
     * @param {string} id
     */
    get(id) {
      if (!id) return Promise.resolve(validationError("a contact id"));
      return run({ method: "GET", path: `/contacts/${id}` });
    },
    /**
     * @param {string} id
     * @param {object} [params]
     * @param {string} [params.email]
     * @param {object} [params.data]
     * @param {boolean} [params.subscribed]
     */
    update(id, { email, data, subscribed } = {}) {
      if (!id) return Promise.resolve(validationError("a contact id"));
      const payload = {
        ...(email !== undefined ? { email } : {}),
        ...(data !== undefined ? { data } : {}),
        ...(subscribed !== undefined ? { subscribed } : {}),
      };
      return run({ method: "PATCH", path: `/contacts/${id}`, payload });
    },
    /**
     * @param {string} id
     */
    remove(id) {
      if (!id) return Promise.resolve(validationError("a contact id"));
      return run({ method: "DELETE", path: `/contacts/${id}` });
    },
    /**
     * @param {object} [params]
     * @param {number} [params.limit]
     * @param {string} [params.cursor]
     * @param {string} [params.search]
     * @param {'subscribed'|'snoozed'|'unsubscribed'} [params.status]
     */
    list(params = {}) {
      const query = new URLSearchParams();
      for (const [key, value] of Object.entries(params)) {
        if (value !== undefined) query.set(key, String(value));
      }
      const qs = query.toString();
      return run({ method: "GET", path: qs ? `/contacts?${qs}` : "/contacts" });
    },
    /**
     * Marks a contact subscribed via track() (track_payload.subscribed), the
     * only subscription-state change reachable with a public/secret key.
     * @param {string} email
     */
    subscribe(email) {
      if (!email) return Promise.resolve(validationError("an email"));
      return track({ event: "subscribe", email, subscribed: true });
    },
    /**
     * @param {string} email
     */
    unsubscribe(email) {
      if (!email) return Promise.resolve(validationError("an email"));
      return track({ event: "unsubscribe", email, subscribed: false });
    },
  };

  return { track, contacts };
}
