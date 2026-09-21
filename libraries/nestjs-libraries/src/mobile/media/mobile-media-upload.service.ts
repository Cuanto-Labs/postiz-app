import {
  S3Client,
  CreateMultipartUploadCommand,
  CompleteMultipartUploadCommand,
  AbortMultipartUploadCommand,
  UploadPartCommand,
  GetObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { BadRequestException, Injectable } from '@nestjs/common';
import path from 'path';
import { makeId } from '@gitroom/nestjs-libraries/services/make.is';
import { UploadFactory } from '@gitroom/nestjs-libraries/upload/upload.factory';
import { getMaxSize } from '@gitroom/nestjs-libraries/upload/custom.upload.validation';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { fileTypeFromBuffer } = require('file-type');

const PART_SIZE = 8 * 1024 * 1024; // 8 MB
const MAX_PART_COUNT = 200;

const BASE_MOBILE_UPLOAD_MIME: Record<string, string> = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.avif': 'image/avif',
  '.mp4': 'video/mp4',
};

function mobileUploadMime(): Record<string, string> {
  return {
    ...BASE_MOBILE_UPLOAD_MIME,
    ...(UploadFactory.processorEnabled() ? { '.mov': 'video/quicktime' } : {}),
  };
}

export interface CreateUploadPart {
  partNumber: number;
  url: string;
}

export interface CreateUploadResult {
  uploadId: string;
  key: string;
  partSize: number;
  parts: CreateUploadPart[];
  expiresAt: Date;
}

export interface CompleteUploadResult {
  key: string;
  location: string;
  mime: string;
}

@Injectable()
export class MobileMediaUploadService {
  private _client?: S3Client;

  private get client(): S3Client {
    if (!this._client) {
      const {
        CLOUDFLARE_ACCOUNT_ID,
        CLOUDFLARE_ACCESS_KEY,
        CLOUDFLARE_SECRET_ACCESS_KEY,
      } = process.env;
      this._client = new S3Client({
        region: 'auto',
        endpoint: `https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com`,
        credentials: {
          accessKeyId: CLOUDFLARE_ACCESS_KEY!,
          secretAccessKey: CLOUDFLARE_SECRET_ACCESS_KEY!,
        },
      });
    }
    return this._client;
  }

  private get bucket(): string {
    return process.env.CLOUDFLARE_BUCKETNAME!;
  }

  private get bucketUrl(): string {
    return process.env.CLOUDFLARE_BUCKET_URL!;
  }

  async createUpload({
    fileName,
    contentType,
    size,
  }: {
    fileName: string;
    contentType?: string;
    size: number;
  }): Promise<CreateUploadResult> {
    const allowed = mobileUploadMime();
    let ext = path.extname(fileName || '').toLowerCase();

    // A client can hand over a name with no usable extension (an iOS photo picker
    // passes the asset identifier). Fall back to the declared content type rather
    // than rejecting an otherwise supported file.
    if (!allowed[ext] && contentType) {
      ext =
        Object.keys(allowed).find((key) => allowed[key] === contentType) ?? ext;
    }

    const expectedMime = allowed[ext];
    if (!expectedMime || (contentType && contentType !== expectedMime)) {
      throw new BadRequestException('Unsupported file type.');
    }

    if (size > getMaxSize(expectedMime)) {
      throw new BadRequestException('File is too large.');
    }

    const key = `${makeId(20)}${ext}`;

    const created = await this.client.send(
      new CreateMultipartUploadCommand({
        Bucket: this.bucket,
        Key: key,
        ContentType: expectedMime,
      })
    );

    const partSize = PART_SIZE;
    const partCount = Math.ceil(size / partSize);
    if (partCount > MAX_PART_COUNT) {
      throw new BadRequestException('File is too large.');
    }

    const uploadId = created.UploadId!;
    const parts: CreateUploadPart[] = [];
    for (let partNumber = 1; partNumber <= partCount; partNumber += 1) {
      const command = new UploadPartCommand({
        Bucket: this.bucket,
        Key: key,
        PartNumber: partNumber,
        UploadId: uploadId,
      });
      const url = await getSignedUrl(this.client, command, {
        expiresIn: 3600,
      });
      parts.push({ partNumber, url });
    }

    return {
      uploadId,
      key,
      partSize,
      parts,
      expiresAt: new Date(Date.now() + 3600 * 1000),
    };
  }

  async completeUpload({
    key,
    uploadId,
    parts,
  }: {
    key: string;
    uploadId: string;
    parts: { partNumber: number; etag: string }[];
  }): Promise<CompleteUploadResult> {
    await this.client.send(
      new CompleteMultipartUploadCommand({
        Bucket: this.bucket,
        Key: key,
        UploadId: uploadId,
        MultipartUpload: {
          Parts: parts.map((part) => ({
            PartNumber: part.partNumber,
            ETag: part.etag,
          })),
        },
      })
    );

    const ext = path.extname(key || '').toLowerCase();
    const expectedMime = mobileUploadMime()[ext];

    const head = await this.client.send(
      new GetObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Range: 'bytes=0-4100',
      })
    );
    const chunks: Buffer[] = [];
    // @ts-ignore
    for await (const chunk of head.Body as AsyncIterable<Buffer>) {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    const prefix = Buffer.concat(chunks);
    const detected = await fileTypeFromBuffer(prefix);

    if (!expectedMime || !detected || detected.mime !== expectedMime) {
      await this.client.send(
        new DeleteObjectCommand({ Bucket: this.bucket, Key: key })
      );
      throw new BadRequestException({
        msg: 'File contents do not match declared type.',
      });
    }

    return {
      key,
      location: `${this.bucketUrl}/${key}`,
      mime: detected.mime,
    };
  }

  async abortUpload({
    key,
    uploadId,
  }: {
    key: string;
    uploadId: string;
  }): Promise<void> {
    try {
      await this.client.send(
        new AbortMultipartUploadCommand({
          Bucket: this.bucket,
          Key: key,
          UploadId: uploadId,
        })
      );
    } catch (err: any) {
      if (err?.name === 'NoSuchUpload' || err?.Code === 'NoSuchUpload') {
        return;
      }
      throw err;
    }
  }
}
