import { NextRequest, NextResponse } from 'next/server';

// api.socials.cuantolabs.com is the backend's public hostname. It is attached to
// this Vercel project (that is where its certificate comes from), but the app
// itself must not answer on it — every path has to reach the self-hosted backend
// on deb instead.
//
// This lives in middleware rather than in a rewrite because both rewrite layers
// were tried first and lost the race: a host-scoped rule in vercel.json and the
// same rule in next.config's rewrites.beforeFiles both let the request through to
// the app's own routing, which 307s unmatched paths to /auth. Middleware runs
// before routing, so it wins.
const API_HOST = 'api.socials.cuantolabs.com';
const BACKEND =
  process.env.BACKEND_INTERNAL_URL || 'https://deb.tail789fa0.ts.net';

export function middleware(request: NextRequest) {
  const host = request.headers.get('host')?.split(':')[0];
  if (host !== API_HOST) {
    return NextResponse.next();
  }

  const target = new URL(
    `${request.nextUrl.pathname}${request.nextUrl.search}`,
    BACKEND
  );
  return NextResponse.rewrite(target);
}

export const config = {
  // Everything except Next's own static output — those never need proxying and
  // keeping them out avoids paying middleware on every asset request.
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
