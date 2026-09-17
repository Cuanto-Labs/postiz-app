import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ApiModule } from '@gitroom/backend/api/api.module';
import { MobileAuthController } from '@gitroom/backend/api/routes/mobile/mobile-auth.controller';
import { MobileDevicesController } from '@gitroom/backend/api/routes/mobile/mobile-devices.controller';
import { MobileChannelsController } from '@gitroom/backend/api/routes/mobile/mobile-channels.controller';
import { MobileMeController } from '@gitroom/backend/api/routes/mobile/mobile-me.controller';
import { MobileConfigController } from '@gitroom/backend/api/routes/mobile/mobile-config.controller';
import { MobilePostsController } from '@gitroom/backend/api/routes/mobile/mobile-posts.controller';
import { MobileAuthService } from '@gitroom/nestjs-libraries/mobile/mobile-auth.service';
import { MobileTokenService } from '@gitroom/nestjs-libraries/mobile/mobile-token.service';
import { MobileSessionRepository } from '@gitroom/nestjs-libraries/mobile/mobile-session.repository';
import { MobileAuthMiddleware } from '@gitroom/backend/api/routes/mobile/mobile-auth.middleware';
import { MobileOAuthService } from '@gitroom/backend/api/routes/mobile/mobile-oauth.service';
import { IdempotencyRepository } from '@gitroom/nestjs-libraries/mobile/idempotency.repository';
import { MobileIdempotencyInterceptor } from '@gitroom/backend/api/routes/mobile/mobile-idempotency.interceptor';
import { PermissionsService } from '@gitroom/backend/services/auth/permissions/permissions.service';

const authenticatedControllers = [
  MobileDevicesController,
  MobileMeController,
  MobileChannelsController,
  MobilePostsController,
];

@Module({
  imports: [ApiModule],
  controllers: [
    MobileAuthController,
    MobileConfigController,
    ...authenticatedControllers,
  ],
  providers: [
    MobileTokenService,
    MobileSessionRepository,
    MobileAuthService,
    MobileAuthMiddleware,
    MobileOAuthService,
    IdempotencyRepository,
    MobileIdempotencyInterceptor,
    PermissionsService,
  ],
})
export class MobileModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(MobileAuthMiddleware).forRoutes(...authenticatedControllers);
  }
}
