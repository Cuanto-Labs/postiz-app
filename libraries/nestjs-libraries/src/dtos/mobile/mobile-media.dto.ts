import {
  IsInt,
  IsOptional,
  IsString,
  Min,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class MobileMediaCreateUploadDto {
  @IsString()
  @MaxLength(255)
  fileName: string;

  @IsString()
  contentType: string;

  @IsInt()
  @Min(1)
  size: number;
}

export class MobileMediaUploadPartDto {
  @IsInt()
  @Min(1)
  partNumber: number;

  @IsString()
  etag: string;
}

export class MobileMediaCompleteUploadDto {
  @IsString()
  key: string;

  @IsString()
  uploadId: string;

  @ValidateNested({ each: true })
  @Type(() => MobileMediaUploadPartDto)
  parts: MobileMediaUploadPartDto[];

  @IsOptional()
  @IsString()
  originalName?: string;
}

export class MobileMediaAbortUploadDto {
  @IsString()
  key: string;

  @IsString()
  uploadId: string;
}

export class MobileMediaListQueryDto {
  // Query strings are strings; without the transform this rejects every ?page=N
  // with "page must be an integer number".
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @IsString()
  search?: string;
}
