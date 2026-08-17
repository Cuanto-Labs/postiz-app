// Proxy for the self-hosted backend, replacing the static /api/:path* rewrite in
// vercel.json.
//
// Why it exists: the origin is exposed through a Tailscale Funnel, and Vercel's
// edge -> Funnel hop fails intermittently (~3 in 10 requests answered 502 on
// 2026-08-17, while the Funnel answered 12/12 when hit directly). A 502 reaches
// the client as a non-JSON body and used to take the page down. Retrying the
// hop clears it, because the failure is in the connection, not the origin.
//
// Retries are GET/HEAD only. A 502 on a POST cannot be distinguished from "the
// origin processed it and the response was lost", and replaying a publish or a
// channel connect is worse than surfacing the error.
//
// Node runtime: the edge runtime could not reach the Funnel host at all (every
// fetch failed with 'internal error'). Request bodies are therefore subject to
// Vercel's 4.5MB function body cap.
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const ORIGIN = process.env.BACKEND_ORIGIN_URL || 'https://deb.tail789fa0.ts.net';
const RETRY_STATUSES = new Set([502, 503, 504]);
const MAX_ATTEMPTS = 3;
const BACKOFF_MS = 150;

// Hop-by-hop and Vercel-injected headers that must not be forwarded upstream.
const STRIP_REQUEST_HEADERS = new Set([
  'host',
  'connection',
  'keep-alive',
  'transfer-encoding',
  'upgrade',
  'x-forwarded-host',
]);

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function proxy(request: Request, path: string[]): Promise<Response> {
  const incoming = new URL(request.url);
  const target = `${ORIGIN}/${path.join('/')}${incoming.search}`;

  const headers = new Headers();
  request.headers.forEach((value, key) => {
    if (!STRIP_REQUEST_HEADERS.has(key.toLowerCase())) {
      headers.set(key, value);
    }
  });

  const idempotent = request.method === 'GET' || request.method === 'HEAD';
  const body = idempotent ? undefined : request.body;
  const attempts = idempotent ? MAX_ATTEMPTS : 1;

  let lastError: unknown = null;

  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      const response = await fetch(target, {
        method: request.method,
        headers,
        body,
        redirect: 'manual',
        // @ts-ignore — required by undici/edge when streaming a request body
        duplex: body ? 'half' : undefined,
      });

      if (RETRY_STATUSES.has(response.status) && attempt < attempts) {
        await sleep(BACKOFF_MS * attempt);
        continue;
      }

      // Pass the response through untouched — Postiz reads auth/showorg/reload/
      // onboarding/logout off these headers to drive the client session.
      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers,
      });
    } catch (error) {
      lastError = error;
      if (attempt < attempts) {
        await sleep(BACKOFF_MS * attempt);
        continue;
      }
    }
  }

  return new Response(
    JSON.stringify({
      message: 'The server is temporarily unreachable. Please try again.',
      detail: lastError instanceof Error ? lastError.message : undefined,
    }),
    { status: 503, headers: { 'content-type': 'application/json' } }
  );
}

type Ctx = { params: Promise<{ path: string[] }> };

const handler = async (request: Request, ctx: Ctx) => {
  const { path } = await ctx.params;
  return proxy(request, path || []);
};

export const GET = handler;
export const HEAD = handler;
export const POST = handler;
export const PUT = handler;
export const PATCH = handler;
export const DELETE = handler;
export const OPTIONS = handler;
