import { IsBoolean } from 'class-validator';

export class MobilePlugActivateDto {
  @IsBoolean()
  status: boolean;
}
