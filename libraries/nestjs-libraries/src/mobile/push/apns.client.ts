import { Injectable, Optional } from '@nestjs/common';
import * as http2 from 'http2';
import { sign } from 'crypto';

export interface ApnsTransport {
  send(input: {
    host: string;
    path: string;
    headers: Record<string, string>;
    body: string;
  }): Promise<{ status: number; body: string }>;
}

export class Http2ApnsTransport implements ApnsTransport {
  send(input: {
    host: string;
    path: string;
    headers: Record<string, string>;
    body: string;
  }): Promise<{ status: number; body: string }> {
    return new Promise((resolve, reject) => {
      const client = http2.connect(input.host);
      client.on('error', (err) => reject(err));

      const req = client.request({
        ':method': 'POST',
        ':path': input.path,
        ...input.headers,
      });

      let status = 0;
      let body = '';

      req.on('response', (headers) => {
        status = Number(headers[':status']) || 0;
      });

      req.setEncoding('utf8');
      req.on('data', (chunk) => {
        body += chunk;
      });

      req.on('end', () => {
        client.close();
        resolve({ status, body });
      });

      req.on('error', (err) => {
        client.close();
        reject(err);
      });

      req.end(input.body);
    });
  }
}

export interface ApnsSendResult {
  ok: boolean;
  status: number;
  reason?: string;
  unregistered: boolean;
}

const PROVIDER_TOKEN_TTL_MS = 50 * 60 * 1000;

const defaultSleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

@Injectable()
export class ApnsClient {
  private cachedToken: { token: string; issuedAt: number } | undefined;

  constructor(
    @Optional() private readonly transport: ApnsTransport = new Http2ApnsTransport(),
    @Optional() private readonly sleep: (ms: number) => Promise<void> = defaultSleep
  ) {}

  isConfigured(): boolean {
    return !!(
      process.env.APNS_KEY_ID &&
      process.env.APNS_TEAM_ID &&
      process.env.APNS_PRIVATE_KEY
    );
  }

  private defaultTopic(): string {
    return process.env.APNS_DEFAULT_TOPIC || 'com.cuantolabs.socials';
  }

  private base64url(input: Buffer | string): string {
    return Buffer.from(input as any)
      .toString('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  }

  private freshProviderToken(): string {
    const keyId = process.env.APNS_KEY_ID!;
    const teamId = process.env.APNS_TEAM_ID!;
    const privateKey = process.env.APNS_PRIVATE_KEY!.replace(/\\n/g, '\n');

    const header = this.base64url(
      JSON.stringify({ alg: 'ES256', kid: keyId })
    );
    const claims = this.base64url(
      JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) })
    );
    const data = `${header}.${claims}`;

    const signature = sign('sha256', Buffer.from(data), {
      key: privateKey,
      dsaEncoding: 'ieee-p1363',
    } as any);

    return `${data}.${this.base64url(signature)}`;
  }

  providerToken(force = false): string {
    if (
      !force &&
      this.cachedToken &&
      Date.now() - this.cachedToken.issuedAt < PROVIDER_TOKEN_TTL_MS
    ) {
      return this.cachedToken.token;
    }

    const token = this.freshProviderToken();
    this.cachedToken = { token, issuedAt: Date.now() };
    return token;
  }

  async send(input: {
    token: string;
    environment: 'sandbox' | 'production';
    topic?: string;
    payload: object;
    collapseId?: string;
    pushType?: string;
    priority?: number;
  }): Promise<ApnsSendResult> {
    if (!this.isConfigured()) {
      return { ok: false, status: 0, reason: 'not_configured', unregistered: false };
    }

    const host =
      input.environment === 'sandbox'
        ? 'https://api.sandbox.push.apple.com'
        : 'https://api.push.apple.com';
    const path = `/3/device/${input.token}`;
    const pushType = input.pushType || 'alert';
    const priority = input.priority ?? 10;

    let attempt = 0;
    let expiredRetried = false;

    while (true) {
      attempt++;

      const headers: Record<string, string> = {
        authorization: `bearer ${this.providerToken()}`,
        'apns-topic': input.topic || this.defaultTopic(),
        'apns-push-type': pushType,
        'apns-priority': String(priority),
      };
      if (input.collapseId) {
        headers['apns-collapse-id'] = input.collapseId;
      }

      let response: { status: number; body: string };
      try {
        response = await this.transport.send({
          host,
          path,
          headers,
          body: JSON.stringify(input.payload),
        });
      } catch {
        return { ok: false, status: 0, reason: 'transport', unregistered: false };
      }

      const { status, body } = response;

      if (status >= 200 && status < 300) {
        return { ok: true, status, unregistered: false };
      }

      let reason: string | undefined;
      try {
        reason = body ? JSON.parse(body).reason : undefined;
      } catch {
        reason = undefined;
      }

      if (status === 410 || (status === 400 && (reason === 'BadDeviceToken' || reason === 'Unregistered'))) {
        return { ok: false, status, reason, unregistered: true };
      }

      if (status === 403 && reason === 'ExpiredProviderToken' && !expiredRetried) {
        expiredRetried = true;
        this.cachedToken = undefined;
        continue;
      }

      if ((status === 429 || status >= 500) && attempt < 3) {
        await this.sleep(500 * Math.pow(2, attempt - 1));
        continue;
      }

      if (status === 429 || status >= 500) {
        return { ok: false, status, reason, unregistered: false };
      }

      return { ok: false, status, reason, unregistered: false };
    }
  }
}
