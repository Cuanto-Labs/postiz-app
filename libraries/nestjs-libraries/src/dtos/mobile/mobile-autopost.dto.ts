import { IsBoolean, IsDefined } from 'class-validator';

export class MobileAutopostActiveDto {
  @IsBoolean()
  @IsDefined()
  active: boolean;
}
