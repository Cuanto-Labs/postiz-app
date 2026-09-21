import { IsString } from 'class-validator';

export class MobileChannelNameDto {
  @IsString()
  name: string;
}

export class MobileChannelGroupDto {
  @IsString()
  group: string;
}

export class MobileChannelSettingsDto {
  @IsString()
  additionalSettings: string;
}
