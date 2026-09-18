jest.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: jest.fn(async (_client: any, command: any) => {
    return `https://signed/${command.input.PartNumber}`;
  }),
}));

jest.mock('file-type', () => ({
  fileTypeFromBuffer: jest.fn(),
}));

jest.mock('@gitroom/nestjs-libraries/upload/custom.upload.validation', () => {
  const actual = jest.requireActual(
    '@gitroom/nestjs-libraries/upload/custom.upload.validation'
  );
  return { ...actual, getMaxSize: jest.fn(actual.getMaxSize) };
});

process.env.CLOUDFLARE_ACCOUNT_ID = 'acct';
process.env.CLOUDFLARE_ACCESS_KEY = 'key';
process.env.CLOUDFLARE_SECRET_ACCESS_KEY = 'secret';
process.env.CLOUDFLARE_BUCKETNAME = 'bucket';
process.env.CLOUDFLARE_BUCKET_URL = 'https://cdn.example.com';

import { MobileMediaUploadService } from '@gitroom/nestjs-libraries/mobile/media/mobile-media-upload.service';
import { getMaxSize } from '@gitroom/nestjs-libraries/upload/custom.upload.validation';
import {
  CreateMultipartUploadCommand,
  CompleteMultipartUploadCommand,
  AbortMultipartUploadCommand,
  GetObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { fileTypeFromBuffer } = require('file-type');

function makeService(sendImpl: (command: any) => any) {
  const svc = new MobileMediaUploadService();
  const fakeClient = { send: jest.fn(sendImpl) };
  (svc as any)._client = fakeClient;
  return { svc, fakeClient };
}

describe('MobileMediaUploadService', () => {
  afterEach(() => {
    (getMaxSize as jest.Mock).mockClear();
    (fileTypeFromBuffer as jest.Mock).mockReset();
  });

  describe('createUpload', () => {
    it('mints a multipart upload with presigned part urls', async () => {
      const { svc, fakeClient } = makeService((command: any) => {
        if (command instanceof CreateMultipartUploadCommand) {
          expect(command.input).toMatchObject({
            Bucket: 'bucket',
            ContentType: 'image/png',
          });
          return { UploadId: 'up-1' };
        }
        throw new Error(`unexpected command ${command.constructor.name}`);
      });

      const result = await svc.createUpload({
        fileName: 'photo.png',
        contentType: 'image/png',
        size: 1024,
      });

      expect(result.uploadId).toBe('up-1');
      expect(result.key.endsWith('.png')).toBe(true);
      expect(result.partSize).toBe(8 * 1024 * 1024);
      expect(result.parts).toEqual([{ partNumber: 1, url: 'https://signed/1' }]);
      expect(result.expiresAt).toBeInstanceOf(Date);
      expect(fakeClient.send).toHaveBeenCalledWith(
        expect.any(CreateMultipartUploadCommand)
      );
    });

    it('signs one UploadPartCommand per part', async () => {
      const { svc } = makeService((command: any) => {
        if (command instanceof CreateMultipartUploadCommand) {
          return { UploadId: 'up-2' };
        }
        throw new Error('unexpected');
      });

      const size = 20 * 1024 * 1024; // 20MB -> 3 parts at 8MB
      const result = await svc.createUpload({
        fileName: 'clip.mp4',
        contentType: 'video/mp4',
        size,
      });

      expect(result.parts.map((p) => p.partNumber)).toEqual([1, 2, 3]);
      expect(result.parts.map((p) => p.url)).toEqual([
        'https://signed/1',
        'https://signed/2',
        'https://signed/3',
      ]);
    });

    it('rejects an unsupported extension with 400', async () => {
      const { svc } = makeService(() => {
        throw new Error('should not call client');
      });

      await expect(
        svc.createUpload({
          fileName: 'evil.exe',
          contentType: 'application/octet-stream',
          size: 10,
        })
      ).rejects.toMatchObject({ status: 400 });
    });

    it('falls back to the content type when the file name carries no extension', async () => {
      // An iOS picker passes the PHAsset identifier ("…/L0/001") as the file name.
      const { svc } = makeService((command: any) => {
        if (command instanceof CreateMultipartUploadCommand) {
          return { UploadId: 'upload-1' };
        }
        throw new Error('unexpected command');
      });

      const result = await svc.createUpload({
        fileName: 'B84E8479-475C-4727-A4A4-B77AA9980897/L0/001',
        contentType: 'image/jpeg',
        size: 10,
      });

      expect(result.key.endsWith('.jpg')).toBe(true);
    });

    it('rejects when contentType does not match the extension', async () => {
      const { svc } = makeService(() => {
        throw new Error('should not call client');
      });

      await expect(
        svc.createUpload({
          fileName: 'photo.png',
          contentType: 'image/gif',
          size: 10,
        })
      ).rejects.toMatchObject({ status: 400 });
    });

    it('rejects a size over the per-mime cap with 400', async () => {
      const { svc } = makeService(() => {
        throw new Error('should not call client');
      });

      await expect(
        svc.createUpload({
          fileName: 'photo.png',
          contentType: 'image/png',
          size: 11 * 1024 * 1024, // > 10MB image cap
        })
      ).rejects.toMatchObject({ status: 400 });
    });

    it('rejects when the computed part count exceeds 200', async () => {
      (getMaxSize as jest.Mock).mockImplementationOnce(() => Number.MAX_SAFE_INTEGER);

      const { svc } = makeService((command: any) => {
        if (command instanceof CreateMultipartUploadCommand) {
          return { UploadId: 'up-3' };
        }
        throw new Error('unexpected');
      });

      await expect(
        svc.createUpload({
          fileName: 'huge.mp4',
          contentType: 'video/mp4',
          size: 201 * 8 * 1024 * 1024,
        })
      ).rejects.toMatchObject({ status: 400 });
    });
  });

  describe('completeUpload', () => {
    it('completes the multipart upload and returns the location on a matching sniff', async () => {
      (fileTypeFromBuffer as jest.Mock).mockResolvedValueOnce({
        ext: 'png',
        mime: 'image/png',
      });

      const { svc, fakeClient } = makeService(async (command: any) => {
        if (command instanceof CompleteMultipartUploadCommand) {
          expect(command.input).toMatchObject({
            Bucket: 'bucket',
            Key: 'abc123.png',
            UploadId: 'up-1',
            MultipartUpload: { Parts: [{ PartNumber: 1, ETag: 'etag1' }] },
          });
          return {};
        }
        if (command instanceof GetObjectCommand) {
          expect(command.input).toMatchObject({
            Bucket: 'bucket',
            Key: 'abc123.png',
            Range: 'bytes=0-4100',
          });
          return {
            Body: (async function* () {
              yield Buffer.from('fake-png-bytes');
            })(),
          };
        }
        throw new Error(`unexpected command ${command.constructor.name}`);
      });

      const result = await svc.completeUpload({
        key: 'abc123.png',
        uploadId: 'up-1',
        parts: [{ partNumber: 1, etag: 'etag1' }],
      });

      expect(result).toEqual({
        key: 'abc123.png',
        location: 'https://cdn.example.com/abc123.png',
        mime: 'image/png',
      });
      expect(fakeClient.send).toHaveBeenCalledWith(
        expect.any(CompleteMultipartUploadCommand)
      );
    });

    it('aborts and throws 400 when the sniffed type does not match the declared extension', async () => {
      (fileTypeFromBuffer as jest.Mock).mockResolvedValueOnce({
        ext: 'exe',
        mime: 'application/x-msdownload',
      });

      const { svc, fakeClient } = makeService(async (command: any) => {
        if (command instanceof CompleteMultipartUploadCommand) {
          return {};
        }
        if (command instanceof GetObjectCommand) {
          return {
            Body: (async function* () {
              yield Buffer.from('not-really-a-png');
            })(),
          };
        }
        if (command instanceof DeleteObjectCommand) {
          expect(command.input).toMatchObject({
            Bucket: 'bucket',
            Key: 'abc123.png',
          });
          return {};
        }
        throw new Error(`unexpected command ${command.constructor.name}`);
      });

      await expect(
        svc.completeUpload({
          key: 'abc123.png',
          uploadId: 'up-1',
          parts: [{ partNumber: 1, etag: 'etag1' }],
        })
      ).rejects.toMatchObject({
        status: 400,
        response: { msg: 'File contents do not match declared type.' },
      });

      expect(fakeClient.send).toHaveBeenCalledWith(
        expect.any(DeleteObjectCommand)
      );
    });
  });

  describe('abortUpload', () => {
    it('sends AbortMultipartUploadCommand', async () => {
      const { svc, fakeClient } = makeService(async (command: any) => {
        if (command instanceof AbortMultipartUploadCommand) {
          expect(command.input).toMatchObject({
            Bucket: 'bucket',
            Key: 'abc123.png',
            UploadId: 'up-1',
          });
          return {};
        }
        throw new Error('unexpected');
      });

      await svc.abortUpload({ key: 'abc123.png', uploadId: 'up-1' });
      expect(fakeClient.send).toHaveBeenCalledWith(
        expect.any(AbortMultipartUploadCommand)
      );
    });

    it('swallows a NoSuchUpload error', async () => {
      const { svc } = makeService(async () => {
        const err: any = new Error('gone');
        err.name = 'NoSuchUpload';
        throw err;
      });

      await expect(
        svc.abortUpload({ key: 'abc123.png', uploadId: 'up-1' })
      ).resolves.toBeUndefined();
    });

    it('rethrows other errors', async () => {
      const { svc } = makeService(async () => {
        throw new Error('boom');
      });

      await expect(
        svc.abortUpload({ key: 'abc123.png', uploadId: 'up-1' })
      ).rejects.toThrow('boom');
    });
  });
});
