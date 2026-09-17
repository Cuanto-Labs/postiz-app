import { IsDateString, IsIn, IsOptional, IsString } from 'class-validator';

export class MobilePostsQueryDto {
  @IsDateString()
  from: string;

  @IsDateString()
  to: string;

  @IsOptional()
  @IsString()
  customer?: string;
}

export class MobileRescheduleDto {
  @IsDateString()
  date: string;

  @IsOptional()
  @IsIn(['schedule', 'update'])
  action?: 'schedule' | 'update';
}
