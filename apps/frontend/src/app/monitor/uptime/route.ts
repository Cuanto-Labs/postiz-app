import { NextResponse } from 'next/server';

// Off-fleet uptime probe, run by Vercel Cron (see "crons" in vercel.json).
//
// Everything else that watches this backend runs at home: fleet-watchdog on the
// Mac mini and postiz-guard.sh on deb itself. One power cut or one dead ISP link
// takes out the service AND every watcher of it at the same time — which is the
// shape of the failure that let the Railway backend stay down for ~2 months
// unnoticed. This check runs on Vercel's infrastructure, so it survives that.
//
// It deliberately probes BACKEND_INTERNAL_URL (the Tailscale Funnel origin)
// rather than a relative path, so the hop it exercises is the fragile one:
// public internet -> funnel -> deb container.
export const dynamic = 'force-dynamic';

const BACKEND =
  process.env.BACKEND_INTERNAL_URL || 'https://deb.tail789fa0.ts.net';

export async function GET(request: Request) {
  const secret = process.env.CRON_SECRET;
  if (secret && request.headers.get('authorization') !== `Bearer ${secret}`) {
    return new NextResponse('unauthorized', { status: 401 });
  }

  let ok = false;
  let detail = '';
  try {
    const res = await fetch(`${BACKEND}/health/status`, {
      cache: 'no-store',
      signal: AbortSignal.timeout(10000),
    });
    const body = await res.text();
    ok = res.ok && body.includes('"status":"ok"');
    detail = `${res.status} ${body.slice(0, 80)}`;
  } catch (err) {
    detail = String(err).slice(0, 120);
  }

  if (!ok && process.env.NTFY_TOPIC) {
    // Fire-and-forget: a failed page must not turn into a failed cron run.
    await fetch(`https://ntfy.sh/${process.env.NTFY_TOPIC}`, {
      method: 'POST',
      headers: {
        Title: 'postiz',
        Priority: 'high',
        Tags: 'rotating_light',
      },
      body: `postiz backend unreachable from Vercel cron: ${detail}`,
    }).catch(() => undefined);
  }

  return NextResponse.json({
    ok,
    detail,
    backend: BACKEND,
    checkedAt: new Date().toISOString(),
  });
}
