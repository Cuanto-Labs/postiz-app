/**
 * Payload CMS v3 email adapter backed by @cuantolabs/mail.
 * Plain ESM + JSDoc, no TypeScript build step. No import of payload packages.
 */

import { createMail } from "./client.js";
import { MailError } from "./errors.js";

/**
 * @param {string|{name?: string, address: string}} [address]
 * @returns {string|undefined}
 */
function formatAddress(address) {
  if (address === undefined || address === null || typeof address === "string") {
    return address;
  }
  return address.name ? `${address.name} <${address.address}>` : address.address;
}

/**
 * @param {string|{name?: string, address: string}|Array<string|{name?: string, address: string}>} to
 * @returns {string|string[]|undefined}
 */
function formatRecipients(to) {
  if (Array.isArray(to)) {
    return to.map(formatAddress);
  }
  return formatAddress(to);
}

/**
 * Payload v3 EmailAdapter factory. Returns `({payload}) => EmailAdapter`, the
 * shape Payload's `email` config option expects.
 *
 * @param {object} [config]
 * @param {string} [config.defaultFromAddress]
 * @param {string} [config.defaultFromName]
 * @param {string} [config.apiKey]
 * @param {string} [config.apiUrl]
 * @param {typeof fetch} [config.fetch]
 * @param {number} [config.retries]
 * @param {(ms: number) => Promise<void>} [config.sleep]
 * @returns {(args: {payload: unknown}) => {
 *   name: string,
 *   defaultFromAddress: string|undefined,
 *   defaultFromName: string|undefined,
 *   sendEmail: (message: object) => Promise<void>,
 * }}
 */
export function payloadAdapter({ defaultFromAddress, defaultFromName, ...mailOpts } = {}) {
  const mail = createMail({ from: defaultFromAddress, ...mailOpts });

  return ({ payload } = {}) => ({
    name: "cuanto-mail",
    defaultFromAddress,
    defaultFromName,

    /**
     * Nodemailer-style message, mapped to send() and thrown on error
     * (Payload's EmailAdapter contract expects sendEmail to throw, not
     * return an error).
     *
     * @param {object} message
     * @param {string|{name?: string, address: string}} [message.from]
     * @param {string|string[]|Array<{name?: string, address: string}>} message.to
     * @param {string} message.subject
     * @param {string} [message.html]
     * @param {string} [message.text]
     * @param {string} [message.replyTo]
     * @returns {Promise<void>}
     */
    async sendEmail(message = {}) {
      const { from, to, subject, html, text, replyTo } = message;

      const { error } = await mail.send({
        from: formatAddress(from),
        to: formatRecipients(to),
        subject,
        html,
        text,
        replyTo,
      });

      if (error) {
        throw error instanceof MailError ? error : new MailError(error?.message ?? "mail send failed", { cause: error });
      }
    },
  });
}
