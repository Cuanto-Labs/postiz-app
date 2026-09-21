import { getMaxSize } from '@gitroom/nestjs-libraries/upload/custom.upload.validation';

export type MediaLimits = {
  maxImages: number;
  maxVideos: number;
  maxImageBytes: number;
  maxVideoBytes: number;
  maxVideoSeconds: number;
  imageMimes: string[];
  videoMimes: string[];
  aspectRatios?: string[];
};

const DEFAULT_IMAGE_MIMES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
const DEFAULT_VIDEO_MIMES = ['video/mp4'];

// Global caps (`getMaxSize`) are the upload-time ceiling; per-provider entries
// below only narrow counts/duration/aspect-ratio, never widen the byte caps.
export const DEFAULT_MEDIA_LIMITS: MediaLimits = {
  maxImages: 10,
  maxVideos: 1,
  maxImageBytes: getMaxSize('image/*'),
  maxVideoBytes: getMaxSize('video/mp4'),
  maxVideoSeconds: 600,
  imageMimes: DEFAULT_IMAGE_MIMES,
  videoMimes: DEFAULT_VIDEO_MIMES,
};

// Per-provider overrides, keyed by `providerIdentifier`. Only fields that
// differ from `DEFAULT_MEDIA_LIMITS` need to be listed; `getMediaLimits`
// merges the rest from the default. Pure lookup table — no branching logic
// belongs in the controller.
export const MEDIA_LIMITS: Record<string, Partial<MediaLimits>> = {
  x: {
    maxImages: 4,
    maxVideos: 1,
    maxVideoSeconds: 140,
  },
  linkedin: {
    maxImages: 9,
    maxVideos: 1,
    maxVideoSeconds: 600,
  },
  'linkedin-page': {
    maxImages: 9,
    maxVideos: 1,
    maxVideoSeconds: 600,
  },
  instagram: {
    maxImages: 10,
    maxVideos: 1,
    maxVideoSeconds: 900,
    aspectRatios: ['1:1', '4:5', '1.91:1'],
  },
  'instagram-standalone': {
    maxImages: 10,
    maxVideos: 1,
    maxVideoSeconds: 900,
    aspectRatios: ['1:1', '4:5', '1.91:1'],
  },
  facebook: {
    maxImages: 10,
    maxVideos: 1,
    maxVideoSeconds: 240 * 60,
  },
  threads: {
    maxImages: 10,
    maxVideos: 1,
    maxVideoSeconds: 300,
  },
  tiktok: {
    maxImages: 35,
    maxVideos: 1,
    maxVideoSeconds: 600,
    aspectRatios: ['9:16'],
  },
  youtube: {
    maxImages: 0,
    maxVideos: 1,
    maxVideoSeconds: 43200,
  },
  pinterest: {
    maxImages: 1,
    maxVideos: 1,
    maxVideoSeconds: 300,
    aspectRatios: ['2:3'],
  },
  bluesky: {
    maxImages: 4,
    maxVideos: 1,
    maxVideoSeconds: 60,
  },
  mastodon: {
    maxImages: 4,
    maxVideos: 1,
    maxVideoSeconds: 300,
  },
  reddit: {
    maxImages: 20,
    maxVideos: 1,
    maxVideoSeconds: 900,
  },
  discord: {
    maxImages: 10,
    maxVideos: 1,
  },
  slack: {
    maxImages: 10,
    maxVideos: 1,
  },
  telegram: {
    maxImages: 10,
    maxVideos: 1,
    maxVideoSeconds: 600,
  },
  nostr: {
    maxImages: 10,
    maxVideos: 1,
  },
  warpcast: {
    maxImages: 2,
    maxVideos: 1,
    maxVideoSeconds: 60,
  },
  lemmy: {
    maxImages: 1,
    maxVideos: 1,
  },
  dribbble: {
    maxImages: 1,
    maxVideos: 0,
    videoMimes: [],
  },
  vk: {
    maxImages: 10,
    maxVideos: 1,
  },
  medium: {
    maxImages: 10,
    maxVideos: 0,
    videoMimes: [],
  },
  hashnode: {
    maxImages: 10,
    maxVideos: 0,
    videoMimes: [],
  },
  devto: {
    maxImages: 10,
    maxVideos: 0,
    videoMimes: [],
  },
  wordpress: {
    maxImages: 10,
    maxVideos: 1,
  },
};

export function getMediaLimits(identifier: string): MediaLimits {
  return {
    ...DEFAULT_MEDIA_LIMITS,
    ...(MEDIA_LIMITS[identifier] || {}),
  };
}
