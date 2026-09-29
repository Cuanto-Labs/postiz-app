import { IsOptional, IsString, MaxLength } from 'class-validator';
import { BRAND_VOICE_MAX_LENGTH } from '@gitroom/nestjs-libraries/chat/ai.provider';

export class BrandVoiceDto {
  @IsOptional()
  @IsString()
  @MaxLength(BRAND_VOICE_MAX_LENGTH)
  brandVoice?: string;
}
