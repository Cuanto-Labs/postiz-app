import {
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  Length,
  MaxLength,
  MinLength,
} from 'class-validator';
import { CreateOrgUserDto } from '@gitroom/nestjs-libraries/dtos/auth/create.org.user.dto';

export class MobileDeviceFields {
  @IsString()
  @MaxLength(128)
  deviceId: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  deviceName?: string;
}

export class MobileLoginDto extends MobileDeviceFields {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(3)
  password: string;
}

export class MobileRegisterDto extends CreateOrgUserDto {
  @IsString()
  @MaxLength(128)
  deviceId: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  deviceName?: string;
}

export class MobileAppleNativeDto extends MobileDeviceFields {
  @IsString()
  @MinLength(20)
  identityToken: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  fullName?: string;
}

export class MobileOAuthStartDto {
  @IsIn(['google'])
  provider: 'google';

  @IsString()
  @Length(43, 128)
  codeChallenge: string;
}

export class MobileOAuthExchangeDto extends MobileDeviceFields {
  @IsIn(['google'])
  provider: 'google';

  @IsString()
  code: string;

  @IsString()
  state: string;

  @IsString()
  @Length(43, 128)
  codeVerifier: string;
}

export class MobileRefreshDto {
  @IsString()
  @MinLength(32)
  refreshToken: string;
}

export class MobileLogoutDto {
  @IsString()
  refreshToken: string;
}
