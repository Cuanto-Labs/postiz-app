import { IsIn } from 'class-validator';

export class MobileDeleteAccountDto {
  @IsIn(['DELETE'])
  confirm: string;
}
