/**
 * @cuantolabs/mail: public type declarations.
 * Hand-written; mirrors the runtime exports of src/index.js exactly.
 */

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

export interface MailErrorOptions {
  statusCode?: number;
  code?: string;
  retryable?: boolean;
  cause?: unknown;
}

export class MailError extends Error {
  name: string;
  statusCode?: number;
  code?: string;
  retryable: boolean;
  cause?: unknown;
  constructor(message: string, options?: MailErrorOptions);
}

export class MailValidationError extends MailError {
  constructor(message: string, options?: MailErrorOptions);
}

export class MailAuthError extends MailError {
  constructor(message: string, options?: MailErrorOptions);
}

export interface MailRateLimitErrorOptions extends MailErrorOptions {
  retryAfterMs?: number;
}

export class MailRateLimitError extends MailError {
  retryAfterMs?: number;
  constructor(message: string, options?: MailRateLimitErrorOptions);
}

export class MailServerError extends MailError {
  constructor(message: string, options?: MailErrorOptions);
}

export class MailNetworkError extends MailError {
  constructor(message: string, options?: MailErrorOptions);
}

export function fromResponse(status: number, body: unknown): MailError;

// ---------------------------------------------------------------------------
// request()
// ---------------------------------------------------------------------------

export interface RequestParams {
  apiUrl: string;
  apiKey: string;
  path?: string;
  method?: string;
  payload?: object;
  fetchImpl: typeof fetch;
  retries: number;
  sleepImpl: (ms: number) => Promise<void>;
}

export function request(params: RequestParams): Promise<any>;

// ---------------------------------------------------------------------------
// send() / createMail()
// ---------------------------------------------------------------------------

export type MailAddress = string | { name?: string; address: string };

export interface SendOptions {
  from?: string;
  to: string | MailAddress | Array<string | MailAddress>;
  subject: string;
  html?: string;
  text?: string;
  react?: unknown;
  replyTo?: string;
  cc?: string | string[];
  bcc?: string | string[];
  tags?: string | string[];
  headers?: Record<string, string>;
  /** String content = already base64; Buffer/Uint8Array is encoded. Max 10. */
  attachments?: MailAttachment[];
}

export interface MailAttachment {
  filename: string;
  content: string | Uint8Array;
  contentType?: string;
}

export interface SendResult {
  data: { id: string } | null;
  error: MailError | null;
}

export interface TrackParams {
  event: string;
  email: string;
  subscribed?: boolean;
  data?: object;
}

export interface MarketingResult<T = any> {
  data: T | null;
  error: MailError | null;
}

export interface ContactCreateParams {
  email: string;
  data?: object;
  subscribed?: boolean;
}

export interface ContactUpdateParams {
  email?: string;
  data?: object;
  subscribed?: boolean;
}

export interface ContactListParams {
  limit?: number;
  cursor?: string;
  search?: string;
  status?: "subscribed" | "snoozed" | "unsubscribed";
}

export interface Contacts {
  create(params: ContactCreateParams): Promise<MarketingResult>;
  get(id: string): Promise<MarketingResult>;
  update(id: string, params?: ContactUpdateParams): Promise<MarketingResult>;
  remove(id: string): Promise<MarketingResult>;
  list(params?: ContactListParams): Promise<MarketingResult>;
  subscribe(email: string): Promise<MarketingResult>;
  unsubscribe(email: string): Promise<MarketingResult>;
}

export interface MailClient {
  send(message: SendOptions): Promise<SendResult>;
  track(params: TrackParams): Promise<MarketingResult>;
  contacts: Contacts;
}

export interface CreateMailConfig {
  apiKey?: string;
  apiUrl?: string;
  from?: string;
  fetch?: typeof fetch;
  retries?: number;
  sleep?: (ms: number) => Promise<void>;
  dev?: string;
}

export function createMail(config?: CreateMailConfig): MailClient;

/** Default send() bound to a lazily-created, env-configured client. */
declare function send(message: SendOptions): Promise<SendResult>;
export { send };
export default send;

/** Default track() bound to a lazily-created, env-configured client. */
export function track(params: TrackParams): Promise<MarketingResult>;

/** Default contacts.* bound to a lazily-created, env-configured client. */
export const contacts: Contacts;
