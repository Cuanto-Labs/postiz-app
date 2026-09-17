import {
  BadRequestException,
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
  UnprocessableEntityException,
} from '@nestjs/common';
import { Observable, of } from 'rxjs';
import { tap } from 'rxjs/operators';
import { createHash } from 'crypto';
import { IdempotencyRepository } from '@gitroom/nestjs-libraries/mobile/idempotency.repository';

export const IDEMPOTENCY_TTL_MS = 24 * 60 * 60 * 1000;

@Injectable()
export class MobileIdempotencyInterceptor implements NestInterceptor {
  constructor(private _idempotencyRepository: IdempotencyRepository) {}

  async intercept(
    context: ExecutionContext,
    next: CallHandler
  ): Promise<Observable<any>> {
    const req = context.switchToHttp().getRequest();
    const res = context.switchToHttp().getResponse();

    const key = req.headers['idempotency-key'] as string | undefined;

    if (!key) {
      return next.handle();
    }

    if (key.length < 8 || key.length > 128) {
      throw new BadRequestException({ msg: 'Invalid Idempotency-Key' });
    }

    // Scope the key per authenticated user so two users in the same org
    // reusing the same client-generated key don't replay each other.
    const scopedKey = `${req.user?.id}:${key}`;

    const requestHash = createHash('sha256')
      .update(req.method + req.path + JSON.stringify(req.body || {}))
      .digest('hex');

    const existing = await this._idempotencyRepository.find(
      req.org.id,
      scopedKey
    );

    if (existing) {
      if (existing.requestHash !== requestHash) {
        throw new UnprocessableEntityException({
          msg: 'Idempotency-Key reused with a different payload',
        });
      }

      res.status(existing.statusCode);
      return of(JSON.parse(existing.response));
    }

    return next.handle().pipe(
      tap(async (body) => {
        try {
          await this._idempotencyRepository.save({
            organizationId: req.org.id,
            key: scopedKey,
            method: req.method,
            path: req.path,
            requestHash,
            statusCode: res.statusCode || 200,
            response: JSON.stringify(body),
            expiresAt: new Date(Date.now() + IDEMPOTENCY_TTL_MS),
          });
        } catch (err: any) {
          // concurrent duplicate request created the row first; ignore
          if (err?.code !== 'P2002') {
            throw err;
          }
        }
      })
    );
  }
}
