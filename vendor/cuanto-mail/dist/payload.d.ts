/**
 * Payload CMS v3 email adapter, type declarations.
 * Hand-written; mirrors the runtime exports of src/payload.js exactly.
 */

import type { CreateMailConfig } from "./index.js";

export interface PayloadAdapterConfig extends CreateMailConfig {
  defaultFromAddress?: string;
  defaultFromName?: string;
}

export interface PayloadMailMessage {
  from?: string | { name?: string; address: string };
  to: string | string[] | Array<{ name?: string; address: string }>;
  subject: string;
  html?: string;
  text?: string;
  replyTo?: string;
}

export interface PayloadEmailAdapter {
  name: string;
  defaultFromAddress: string | undefined;
  defaultFromName: string | undefined;
  sendEmail(message: PayloadMailMessage): Promise<void>;
}

export function payloadAdapter(
  config?: PayloadAdapterConfig,
): (args?: { payload?: unknown }) => PayloadEmailAdapter;
