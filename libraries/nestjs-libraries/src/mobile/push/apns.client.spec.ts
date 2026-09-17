import { generateKeyPairSync } from 'crypto';
import { ApnsClient, ApnsTransport } from './apns.client';

class FakeTransport implements ApnsTransport {
  calls: Array<{
    host: string;
    path: string;
    headers: Record<string, string>;
    body: string;
  }> = [];
  responses: Array<{ status: number; body: string }> = [];

  async send(input: {
    host: string;
    path: string;
    headers: Record<string, string>;
    body: string;
  }): Promise<{ status: number; body: string }> {
    this.calls.push(input);
    const response = this.responses.shift();
    if (!response) {
      throw new Error('no scripted response left');
    }
    return response;
  }
}

describe('ApnsClient', () => {
  let transport: FakeTransport;
  let sleep: jest.Mock;
  let client: ApnsClient;

  beforeAll(() => {
    const { privateKey } = generateKeyPairSync('ec', {
      namedCurve: 'prime256v1',
    });
    const pem = privateKey
      .export({ type: 'pkcs8', format: 'pem' })
      .toString();

    process.env.APNS_KEY_ID = 'key123';
    process.env.APNS_TEAM_ID = 'team123';
    process.env.APNS_PRIVATE_KEY = pem;
  });

  beforeEach(() => {
    transport = new FakeTransport();
    sleep = jest.fn().mockResolvedValue(undefined);
    client = new ApnsClient(transport, sleep);
  });

  it('short-circuits when not configured', async () => {
    delete process.env.APNS_KEY_ID;
    const result = await client.send({
      token: 'devtoken',
      environment: 'sandbox',
      payload: { aps: { alert: 'hi' } },
    });
    expect(result).toEqual({
      ok: false,
      status: 0,
      reason: 'not_configured',
      unregistered: false,
    });
    expect(transport.calls.length).toBe(0);
    process.env.APNS_KEY_ID = 'key123';
  });

  it('sends with bearer auth header, apns-topic, and sandbox host on 200', async () => {
    transport.responses.push({ status: 200, body: '' });

    const result = await client.send({
      token: 'devtoken',
      environment: 'sandbox',
      payload: { aps: { alert: 'hi' } },
    });

    expect(result.ok).toBe(true);
    expect(transport.calls[0].host).toBe('https://api.sandbox.push.apple.com');
    expect(transport.calls[0].headers.authorization).toMatch(/^bearer /);
    expect(transport.calls[0].headers['apns-topic']).toBe(
      'com.cuantolabs.socials'
    );
  });

  it('maps 410 to unregistered', async () => {
    transport.responses.push({
      status: 410,
      body: JSON.stringify({ reason: 'Unregistered' }),
    });

    const result = await client.send({
      token: 'devtoken',
      environment: 'production',
      payload: {},
    });

    expect(result.ok).toBe(false);
    expect(result.unregistered).toBe(true);
  });

  it('maps 400 BadDeviceToken to unregistered', async () => {
    transport.responses.push({
      status: 400,
      body: JSON.stringify({ reason: 'BadDeviceToken' }),
    });

    const result = await client.send({
      token: 'devtoken',
      environment: 'production',
      payload: {},
    });

    expect(result.ok).toBe(false);
    expect(result.unregistered).toBe(true);
  });

  it('retries 429 then succeeds on second call, sleeping once', async () => {
    transport.responses.push({ status: 429, body: '' });
    transport.responses.push({ status: 200, body: '' });

    const result = await client.send({
      token: 'devtoken',
      environment: 'production',
      payload: {},
    });

    expect(result.ok).toBe(true);
    expect(transport.calls.length).toBe(2);
    expect(sleep).toHaveBeenCalledTimes(1);
  });

  it('gives up after 3 attempts on repeated 500s', async () => {
    transport.responses.push({ status: 500, body: '' });
    transport.responses.push({ status: 500, body: '' });
    transport.responses.push({ status: 500, body: '' });

    const result = await client.send({
      token: 'devtoken',
      environment: 'production',
      payload: {},
    });

    expect(result.ok).toBe(false);
    expect(transport.calls.length).toBe(3);
  });

  it('refreshes provider token after ExpiredProviderToken and retries with a fresh one', async () => {
    transport.responses.push({
      status: 403,
      body: JSON.stringify({ reason: 'ExpiredProviderToken' }),
    });
    transport.responses.push({ status: 200, body: '' });

    const result = await client.send({
      token: 'devtoken',
      environment: 'production',
      payload: {},
    });

    expect(result.ok).toBe(true);
    expect(transport.calls.length).toBe(2);
    expect(transport.calls[0].headers.authorization).not.toBe(
      transport.calls[1].headers.authorization
    );
  });
});
