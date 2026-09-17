import { IsNumberString } from 'class-validator';

export class MobileAnalyticsQueryDto {
  @IsNumberString()
  date: string;
}
