import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class MobileAiConsentDto {
  @IsBoolean()
  granted: boolean;
}

export class MobileAiSuggestDto {
  @IsString()
  @MaxLength(5000)
  content: string;

  @IsIn(['variations', 'fit'])
  mode: 'variations' | 'fit';

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10000)
  maxLength?: number;
}
