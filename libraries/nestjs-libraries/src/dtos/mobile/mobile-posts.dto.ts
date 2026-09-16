import { IsDateString, IsOptional, IsString } from 'class-validator';

export class MobilePostsQueryDto {
  @IsDateString()
  from: string;

  @IsDateString()
  to: string;

  @IsOptional()
  @IsString()
  customer?: string;
}
