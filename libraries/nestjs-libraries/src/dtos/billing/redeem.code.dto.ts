import { IsString, MaxLength, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';

export class RedeemCodeDto {
  @IsString()
  @MinLength(2)
  @MaxLength(64)
  // Codes are stored and displayed uppercase; normalise here so a user typing
  // "ronron" is not told their code is invalid.
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value
  )
  code: string;
}
