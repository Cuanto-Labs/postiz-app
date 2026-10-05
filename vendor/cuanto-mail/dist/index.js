/**
 * @cuantolabs/mail: public entry point.
 * Plain ESM + JSDoc, no TypeScript build step.
 */

export {
  MailError,
  MailValidationError,
  MailAuthError,
  MailRateLimitError,
  MailServerError,
  MailNetworkError,
  fromResponse,
} from "./errors.js";

export { createMail, request } from "./client.js";

import { createMail } from "./client.js";

/** @type {ReturnType<typeof createMail>|undefined} */
let singleton;

/**
 * Default send() bound to a lazily-created, env-configured client.
 * @param {Parameters<ReturnType<typeof createMail>['send']>[0]} message
 * @returns {ReturnType<ReturnType<typeof createMail>['send']>}
 */
export default function send(message) {
  if (!singleton) {
    singleton = createMail();
  }
  return singleton.send(message);
}

export { send };

/**
 * Default track() bound to a lazily-created, env-configured client.
 * @param {Parameters<ReturnType<typeof createMail>['track']>[0]} params
 * @returns {ReturnType<ReturnType<typeof createMail>['track']>}
 */
export function track(params) {
  if (!singleton) {
    singleton = createMail();
  }
  return singleton.track(params);
}

/**
 * Default contacts.* bound to a lazily-created, env-configured client.
 */
export const contacts = {
  create: (...args) => (singleton ??= createMail()).contacts.create(...args),
  get: (...args) => (singleton ??= createMail()).contacts.get(...args),
  update: (...args) => (singleton ??= createMail()).contacts.update(...args),
  remove: (...args) => (singleton ??= createMail()).contacts.remove(...args),
  list: (...args) => (singleton ??= createMail()).contacts.list(...args),
  subscribe: (...args) => (singleton ??= createMail()).contacts.subscribe(...args),
  unsubscribe: (...args) => (singleton ??= createMail()).contacts.unsubscribe(...args),
};
