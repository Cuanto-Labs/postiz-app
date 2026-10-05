/**
 * Typed error hierarchy for @cuantolabs/mail.
 * Plain ESM + JSDoc, no TypeScript build step.
 */

/**
 * Base error for all mail-related failures.
 */
export class MailError extends Error {
  /**
   * @param {string} message
   * @param {object} [options]
   * @param {number} [options.statusCode]
   * @param {string} [options.code]
   * @param {boolean} [options.retryable]
   * @param {unknown} [options.cause]
   */
  constructor(message, options = {}) {
    super(message, options.cause !== undefined ? { cause: options.cause } : undefined);
    this.name = "MailError";
    this.statusCode = options.statusCode;
    this.code = options.code;
    this.retryable = options.retryable ?? false;
    if (options.cause !== undefined) {
      this.cause = options.cause;
    }
  }
}

/**
 * Request payload failed validation before it was sent.
 */
export class MailValidationError extends MailError {
  /**
   * @param {string} message
   * @param {object} [options]
   */
  constructor(message, options = {}) {
    super(message, { ...options, retryable: options.retryable ?? false });
    this.name = "MailValidationError";
    this.code = options.code ?? "MAIL_VALIDATION_ERROR";
  }
}

/**
 * Authentication/authorization failure (401/403).
 */
export class MailAuthError extends MailError {
  /**
   * @param {string} message
   * @param {object} [options]
   */
  constructor(message, options = {}) {
    super(message, { ...options, retryable: options.retryable ?? false });
    this.name = "MailAuthError";
    this.statusCode = options.statusCode ?? 401;
    this.code = options.code ?? "MAIL_AUTH_ERROR";
  }
}

/**
 * Provider rate limit exceeded (429).
 */
export class MailRateLimitError extends MailError {
  /**
   * @param {string} message
   * @param {object} [options]
   * @param {number} [options.retryAfterMs]
   */
  constructor(message, options = {}) {
    super(message, { ...options, retryable: options.retryable ?? true });
    this.name = "MailRateLimitError";
    this.statusCode = options.statusCode ?? 429;
    this.code = options.code ?? "MAIL_RATE_LIMIT_ERROR";
    this.retryAfterMs = options.retryAfterMs;
  }
}

/**
 * Provider returned a server-side failure (5xx).
 */
export class MailServerError extends MailError {
  /**
   * @param {string} message
   * @param {object} [options]
   */
  constructor(message, options = {}) {
    super(message, { ...options, retryable: options.retryable ?? true });
    this.name = "MailServerError";
    this.statusCode = options.statusCode ?? 500;
    this.code = options.code ?? "MAIL_SERVER_ERROR";
  }
}

/**
 * Request failed before a response was received (DNS, TCP, timeout, abort).
 */
export class MailNetworkError extends MailError {
  /**
   * @param {string} message
   * @param {object} [options]
   */
  constructor(message, options = {}) {
    super(message, { ...options, retryable: options.retryable ?? true });
    this.name = "MailNetworkError";
    this.code = options.code ?? "MAIL_NETWORK_ERROR";
  }
}

/**
 * Build the appropriate typed error from an HTTP response status + body.
 * @param {number} status
 * @param {unknown} body
 * @returns {MailError}
 */
export function fromResponse(status, body) {
  const message =
    (body && typeof body === "object" && "message" in body && typeof body.message === "string"
      ? body.message
      : undefined) ?? `mail request failed with status ${status}`;

  if (status === 401 || status === 403) {
    return new MailAuthError(message, { statusCode: status, cause: body });
  }
  if (status === 429) {
    const retryAfterMs =
      body && typeof body === "object" && "retryAfterMs" in body && typeof body.retryAfterMs === "number"
        ? body.retryAfterMs
        : undefined;
    return new MailRateLimitError(message, { statusCode: status, retryAfterMs, cause: body });
  }
  if (status >= 500) {
    return new MailServerError(message, { statusCode: status, cause: body });
  }
  if (status >= 400) {
    return new MailValidationError(message, { statusCode: status, cause: body });
  }
  return new MailError(message, { statusCode: status, cause: body });
}
