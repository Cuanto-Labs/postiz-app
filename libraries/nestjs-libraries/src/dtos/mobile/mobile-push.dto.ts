import {
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

const APNS_TOKEN_REGEX = /^[0-9a-f]{64,200}$/i;
const BUNDLE_ID_REGEX = /^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9-]+)+$/;

export class MobilePushDeviceDto {
  @IsString()
  @Matches(APNS_TOKEN_REGEX)
  apnsToken: string;

  @IsIn(['sandbox', 'production'])
  environment: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  @Matches(BUNDLE_ID_REGEX)
  bundleId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(16)
  locale?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  timezone?: string;

  @IsOptional()
  @IsObject()
  prefs?: Record<string, boolean>;
}

export class MobilePushPrefsDto {
  @IsString()
  @Matches(APNS_TOKEN_REGEX)
  apnsToken: string;

  @IsObject()
  prefs: Record<string, boolean>;
}

export class MobilePushPrefsQueryDto {
  @IsString()
  @Matches(APNS_TOKEN_REGEX)
  token: string;
}
