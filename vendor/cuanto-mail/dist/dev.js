/**
 * Dev-mode short-circuit for @cuantolabs/mail send().
 * Plain ESM + JSDoc, no TypeScript build step.
 */

import { MailValidationError } from "./errors.js";

/**
 * @param {string|undefined} value raw MAIL_DEV env/config value
 * @returns {{mode: 'off'|'log'|'redirect', to?: string}}
 */
export function parseDevMode(value) {
  if (value === undefined || value === null || value === "" || value === "off") {
    return { mode: "off" };
  }
  if (value === "log") {
    return { mode: "log" };
  }
  if (value.startsWith("redirect:")) {
    const to = value.slice("redirect:".length);
    if (!to) {
      throw new MailValidationError(`invalid MAIL_DEV value: ${value}`);
    }
    return { mode: "redirect", to };
  }
  throw new MailValidationError(`invalid MAIL_DEV value: ${value}`);
}

/**
 * @param {{to:unknown, subject:string, html?:string, text?:string}} payload
 * @returns {{data:{id:string}, error:null}}
 */
export function devLogSend(payload) {
  const bodyLength = (payload.html ?? payload.text ?? "").length;
  console.info(
    `[mail dev:log] from=${payload.from} to=${JSON.stringify(payload.to)} subject=${JSON.stringify(payload.subject)} bodyLength=${bodyLength}`,
  );
  const id = `dev_${Math.random().toString(36).slice(2)}`;
  return { data: { id }, error: null };
}
