import {
  IsDateString,
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

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

export class MobileOldPostsQueryDto {
  @IsDateString()
  date: string;
}

export class MobileSeparatePostsDto {
  @IsString()
  content: string;

  @IsNumber()
  @Min(1)
  len: number;
}

export class MobileCommentDto {
  @IsString()
  @IsNotEmpty()
  comment: string;
}
