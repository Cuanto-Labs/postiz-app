import { IsString, MaxLength, MinLength } from 'class-validator';
import { VideoDto } from '@gitroom/nestjs-libraries/dtos/videos/video.dto';

export class MobileAiImageDto {
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  prompt: string;
}

export class MobileAiVideoDto extends VideoDto {}
