import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { MobileMediaListQueryDto } from '@gitroom/nestjs-libraries/dtos/mobile/mobile-media.dto';
import 'reflect-metadata';

// mobile.module.ts pulls in ApiModule and MobileAuthController, both of which
// transitively import the real AuthService, which pulls in nostr-tools (ESM)
// that ts-jest's CJS transform cannot require — see
// mobile-auth.controller.spec.ts for the same workaround, applied here to
// every real import MobileModule reaches since only the class reference is
// needed.
jest.mock('@gitroom/backend/api/api.module', () => ({
  ApiModule: class ApiModule {},
}));
jest.mock('@gitroom/backend/services/auth/auth.service', () => ({
  AuthService: class AuthService {},
}));
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/integrations/integration.service',
  () => ({ IntegrationService: class IntegrationService {} })
);
jest.mock(
  '@gitroom/nestjs-libraries/integrations/integration.manager',
  () => ({ IntegrationManager: class IntegrationManager {} })
);
jest.mock(
  '@gitroom/backend/services/auth/permissions/permissions.service',
  () => ({ PermissionsService: class PermissionsService {} })
);
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/posts/posts.service',
  () => ({ PostsService: class PostsService {} })
);
// MobileMediaController imports MediaService directly; MediaService pulls in
// VideoManager/TemporalService/OpenaiService, a heavy real chain that is
// unnecessary here since every test constructs the controller with `as any`
// mocks. Stub the class reference the same way.
jest.mock(
  '@gitroom/nestjs-libraries/database/prisma/media/media.service',
  () => ({ MediaService: class MediaService {} })
);
// MobileMediaUploadService (real, from T060) requires('file-type') at module
// load time; file-type is ESM-only and ts-jest's CJS transform cannot
// require it, so it must be mocked even though the controller mocks the
// service instance itself.
jest.mock('file-type', () => ({ fileTypeFromBuffer: jest.fn() }));

import { MobileMediaController } from '@gitroom/backend/api/routes/mobile/mobile-media.controller';
import { MobileModule } from '@gitroom/backend/api/routes/mobile/mobile.module';
import { MobileMediaUploadService } from '@gitroom/nestjs-libraries/mobile/media/mobile-media-upload.service';

describe('MobileMediaController', () => {
  const org = { id: 'org-1' };

  const makeController = () => {
    const mobileMediaUploadService = {
      createUpload: jest.fn(),
      completeUpload: jest.fn(),
      abortUpload: jest.fn(),
    };
    const mediaService = {
      saveUploadedFile: jest.fn(),
      getMediaStatus: jest.fn(),
      getMedia: jest.fn(),
      deleteMedia: jest.fn(),
      saveMediaInformation: jest.fn(),
    };

    const controller = new MobileMediaController(
      mobileMediaUploadService as any,
      mediaService as any
    );

    return { controller, mobileMediaUploadService, mediaService };
  };

  it('exposes the /mobile/v1/media path', () => {
    expect(Reflect.getMetadata('path', MobileMediaController)).toBe(
      '/mobile/v1/media'
    );
  });

  it('createUpload delegates to MobileMediaUploadService.createUpload', async () => {
    const { controller, mobileMediaUploadService } = makeController();
    const body = { fileName: 'a.jpg', contentType: 'image/jpeg', size: 100 };
    mobileMediaUploadService.createUpload.mockResolvedValue({
      uploadId: 'up-1',
      key: 'key-1',
      partSize: 8000000,
      parts: [],
      expiresAt: new Date(),
    });

    const result = await controller.createUpload(body as any);

    expect(mobileMediaUploadService.createUpload).toHaveBeenCalledWith(body);
    expect(result).toEqual(
      expect.objectContaining({ uploadId: 'up-1', key: 'key-1' })
    );
  });

  it('completeUpload finishes the multipart upload then saves the file and returns a trimmed media object', async () => {
    const { controller, mobileMediaUploadService, mediaService } =
      makeController();
    const body = {
      key: 'key-1',
      uploadId: 'up-1',
      parts: [{ partNumber: 1, etag: 'etag-1' }],
      originalName: 'photo.jpg',
    };
    mobileMediaUploadService.completeUpload.mockResolvedValue({
      key: 'key-1',
      location: 'https://cdn.example.com/key-1',
      mime: 'image/jpeg',
    });
    mediaService.saveUploadedFile.mockResolvedValue({
      id: 'media-1',
      name: 'key-1',
      path: 'https://cdn.example.com/key-1',
      status: 'ready',
      processingError: null,
      thumbnail: null,
      extraField: 'should not leak',
    });

    const result = await controller.completeUpload(org as any, body as any);

    expect(mobileMediaUploadService.completeUpload).toHaveBeenCalledWith(
      body
    );
    expect(mediaService.saveUploadedFile).toHaveBeenCalledWith(
      org.id,
      'key-1',
      'https://cdn.example.com/key-1',
      'photo.jpg'
    );
    expect(result).toEqual({
      media: {
        id: 'media-1',
        name: 'key-1',
        path: 'https://cdn.example.com/key-1',
        status: 'ready',
        processingError: null,
        thumbnail: null,
      },
    });
  });

  it('completeUpload falls back to the key as originalName when none is supplied', async () => {
    const { controller, mobileMediaUploadService, mediaService } =
      makeController();
    const body = {
      key: 'key-2',
      uploadId: 'up-2',
      parts: [{ partNumber: 1, etag: 'etag-1' }],
    };
    mobileMediaUploadService.completeUpload.mockResolvedValue({
      key: 'key-2',
      location: 'https://cdn.example.com/key-2',
      mime: 'video/mp4',
    });
    mediaService.saveUploadedFile.mockResolvedValue({
      id: 'media-2',
      name: 'key-2',
      path: 'https://cdn.example.com/key-2',
      status: 'processing',
      processingError: null,
      thumbnail: null,
    });

    await controller.completeUpload(org as any, body as any);

    expect(mediaService.saveUploadedFile).toHaveBeenCalledWith(
      org.id,
      'key-2',
      'https://cdn.example.com/key-2',
      'key-2'
    );
  });

  it('abortUpload delegates to MobileMediaUploadService.abortUpload and returns { ok: true }', async () => {
    const { controller, mobileMediaUploadService } = makeController();
    const body = { key: 'key-1', uploadId: 'up-1' };

    const result = await controller.abortUpload(body as any);

    expect(mobileMediaUploadService.abortUpload).toHaveBeenCalledWith(body);
    expect(result).toEqual({ ok: true });
  });

  it('status returns the media on success', async () => {
    const { controller, mediaService } = makeController();
    mediaService.getMediaStatus.mockResolvedValue({
      id: 'media-1',
      status: 'ready',
    });

    const result = await controller.status(org as any, 'media-1');

    expect(mediaService.getMediaStatus).toHaveBeenCalledWith(
      org.id,
      'media-1'
    );
    expect(result).toEqual({ id: 'media-1', status: 'ready' });
  });

  it('status throws a 404 with { msg } when the media is not found', async () => {
    const { controller, mediaService } = makeController();
    mediaService.getMediaStatus.mockResolvedValue(null);

    await expect(
      controller.status(org as any, 'missing')
    ).rejects.toMatchObject({
      response: { msg: 'Media not found' },
      status: 404,
    });
  });

  it('list delegates to MediaService.getMedia with the page query', async () => {
    const { controller, mediaService } = makeController();
    mediaService.getMedia.mockResolvedValue([{ id: 'media-1' }]);

    const result = await controller.list(org as any, { page: 2 } as any);

    expect(mediaService.getMedia).toHaveBeenCalledWith(org.id, 2, undefined);
    expect(result).toEqual([{ id: 'media-1' }]);
  });

  it('list forwards the search query to MediaService.getMedia', async () => {
    const { controller, mediaService } = makeController();
    mediaService.getMedia.mockResolvedValue([{ id: 'media-1' }]);

    const result = await controller.list(org as any, {
      page: 2,
      search: 'logo',
    } as any);

    expect(mediaService.getMedia).toHaveBeenCalledWith(org.id, 2, 'logo');
    expect(result).toEqual([{ id: 'media-1' }]);
  });

  it('deleteMedia delegates to MediaService.deleteMedia', async () => {
    const { controller, mediaService } = makeController();
    mediaService.deleteMedia.mockResolvedValue({ id: 'media-1' });

    const result = await controller.deleteMedia(org as any, 'media-1');

    expect(mediaService.deleteMedia).toHaveBeenCalledWith(org.id, 'media-1');
    expect(result).toEqual({ id: 'media-1' });
  });

  it('saveMediaInformation delegates to MediaService.saveMediaInformation', async () => {
    const { controller, mediaService } = makeController();
    const body = { id: 'media-1', alt: 'a photo' };
    mediaService.saveMediaInformation.mockResolvedValue({ id: 'media-1' });

    const result = await controller.saveMediaInformation(
      org as any,
      body as any
    );

    expect(mediaService.saveMediaInformation).toHaveBeenCalledWith(
      org.id,
      body
    );
    expect(result).toEqual({ id: 'media-1' });
  });

  it('accepts ?page=2 from a query string', async () => {
    const dto = plainToInstance(
      MobileMediaListQueryDto,
      { page: '2' },
      { enableImplicitConversion: false }
    );

    expect(await validate(dto)).toEqual([]);
    expect(dto.page).toBe(2);
  });

  it('MobileModule includes MobileMediaController and MobileMediaUploadService', () => {
    const controllers = Reflect.getMetadata('controllers', MobileModule);
    expect(controllers).toContain(MobileMediaController);

    const providers = Reflect.getMetadata('providers', MobileModule);
    expect(providers).toContain(MobileMediaUploadService);
  });
});
