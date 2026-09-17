import { ThrottlerGuard } from '@nestjs/throttler';
import { ExecutionContext, Injectable } from '@nestjs/common';
import { Request } from 'express';

// Throttled paths:
//   POST /public/v1/posts → API_LIMIT/hour per org (public API)
//   POST /copilot/agent   → AI_LIMIT/hour per org (AI chat)
// All other routes are unthrottled.

@Injectable()
export class ThrottlerBehindProxyGuard extends ThrottlerGuard {
  public override async canActivate(
    context: ExecutionContext
  ): Promise<boolean> {
    const { url, method } = context.switchToHttp().getRequest<Request>();
    const isPublicPosts = method === 'POST' && url.includes('/public/v1/posts');
    const isAiAgent = method === 'POST' && url.includes('/copilot/agent');

    if (isPublicPosts || isAiAgent) {
      return super.canActivate(context);
    }

    return true;
  }

  protected override async getTracker(
    req: Record<string, any>
  ): Promise<string> {
    const isAi = req.url.includes('/copilot/');
    return req.org.id + '_' + (isAi ? 'ai' : req.url.indexOf('/posts') > -1 ? 'posts' : 'other');
  }
}

// route-level guard for public endpoints, keyed by the client address the
// proxy forwards rather than the org the global guard expects
@Injectable()
export class ThrottlerRealIpGuard extends ThrottlerGuard {
  protected override async getTracker(
    req: Record<string, any>
  ): Promise<string> {
    const forwarded = String(req.headers?.['x-forwarded-for'] || '');
    return forwarded.split(',')[0].trim() || req.ip;
  }
}
