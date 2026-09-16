import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ApiModule } from '@gitroom/backend/api/api.module';
import { MobileAuthController } from '@gitroom/backend/api/routes/mobile/mobile-auth.controller';
import { MobileDevicesController } from '@gitroom/backend/api/routes/mobile/mobile-devices.controller';
import { MobileChannelsController } from '@gitroom/backend/api/routes/mobile/mobile-channels.controller';
import { MobileAuthService } from '@gitroom/nestjs-libraries/mobile/mobile-auth.service';
import { MobileTokenService } from '@gitroom/nestjs-libraries/mobile/mobile-token.service';
import { MobileSessionRepository } from '@gitroom/nestjs-libraries/mobile/mobile-session.repository';
import { MobileAuthMiddleware } from '@gitroom/backend/api/routes/mobile/mobile-auth.middleware';
import { MobileOAuthService } from '@gitroom/backend/api/routes/mobile/mobile-oauth.service';

const authenticatedControllers = [
  MobileDevicesController,
  MobileChannelsController,
];

@Module({
  imports: [ApiModule],
  controllers: [MobileAuthController, ...authenticatedControllers],
  providers: [
    MobileTokenService,
    MobileSessionRepository,
    MobileAuthService,
    MobileAuthMiddleware,
    MobileOAuthService,
  ],
})
export class MobileModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(MobileAuthMiddleware).forRoutes(...authenticatedControllers);
  }
}
