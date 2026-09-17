import {
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

const APNS_TOKEN_REGEX = /^[0-9a-f]{64,200}$/i;

export class MobilePushDeviceDto {
  @IsString()
  @Matches(APNS_TOKEN_REGEX)
  apnsToken: string;

  @IsIn(['sandbox', 'production'])
  environment: string;

  @IsOptional()
  @IsString()
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
