import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ApiModule } from '@gitroom/backend/api/api.module';
import { MobileAuthController } from '@gitroom/backend/api/routes/mobile/mobile-auth.controller';
import { MobileDevicesController } from '@gitroom/backend/api/routes/mobile/mobile-devices.controller';
import { MobileChannelsController } from '@gitroom/backend/api/routes/mobile/mobile-channels.controller';
import { MobileAnalyticsController } from '@gitroom/backend/api/routes/mobile/mobile-analytics.controller';
import { MobilePlugsController } from '@gitroom/backend/api/routes/mobile/mobile-plugs.controller';
import { MobileMeController } from '@gitroom/backend/api/routes/mobile/mobile-me.controller';
import { MobileConfigController } from '@gitroom/backend/api/routes/mobile/mobile-config.controller';
import { MobilePostsController } from '@gitroom/backend/api/routes/mobile/mobile-posts.controller';
import { MobilePushController } from '@gitroom/backend/api/routes/mobile/mobile-push.controller';
import { MobileMediaController } from '@gitroom/backend/api/routes/mobile/mobile-media.controller';
import { MobileAccountController } from '@gitroom/backend/api/routes/mobile/mobile-account.controller';
import { MobileAiController } from '@gitroom/backend/api/routes/mobile/mobile-ai.controller';
import { MobileTagsController } from '@gitroom/backend/api/routes/mobile/mobile-tags.controller';
import { MobileSignaturesController } from '@gitroom/backend/api/routes/mobile/mobile-signatures.controller';
import { MobileSetsController } from '@gitroom/backend/api/routes/mobile/mobile-sets.controller';
import { MobileAutopostController } from '@gitroom/backend/api/routes/mobile/mobile-autopost.controller';
import { MobileNotificationsController } from '@gitroom/backend/api/routes/mobile/mobile-notifications.controller';
import { MobileOrgController } from '@gitroom/backend/api/routes/mobile/mobile-org.controller';
import { MobileMediaUploadService } from '@gitroom/nestjs-libraries/mobile/media/mobile-media-upload.service';
import { MobileAccountService } from '@gitroom/nestjs-libraries/mobile/account/mobile-account.service';
import { AccountDeletionRepository } from '@gitroom/nestjs-libraries/mobile/account/account-deletion.repository';
import { AiConsentRepository } from '@gitroom/nestjs-libraries/mobile/ai/ai-consent.repository';
import { MobileAiService } from '@gitroom/nestjs-libraries/mobile/ai/mobile-ai.service';
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
  MobileAnalyticsController,
  MobilePlugsController,
  MobilePostsController,
  MobilePushController,
  MobileMediaController,
  MobileAccountController,
  MobileAiController,
  MobileTagsController,
  MobileSignaturesController,
  MobileSetsController,
  MobileAutopostController,
  MobileNotificationsController,
  MobileOrgController,
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
    MobileMediaUploadService,
    MobileAccountService,
    AccountDeletionRepository,
    AiConsentRepository,
    MobileAiService,
  ],
})
export class MobileModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(MobileAuthMiddleware).forRoutes(...authenticatedControllers);
  }
}
