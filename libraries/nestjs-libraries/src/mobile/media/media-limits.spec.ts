import {
  DEFAULT_MEDIA_LIMITS,
  getMediaLimits,
} from '@gitroom/nestjs-libraries/mobile/media/media-limits';

describe('getMediaLimits', () => {
  it('returns the defaults for an unknown identifier', () => {
    expect(getMediaLimits('some-unknown-provider')).toEqual(
      DEFAULT_MEDIA_LIMITS
    );
  });

  it('returns x-specific image limits', () => {
    expect(getMediaLimits('x').maxImages).toBe(4);
  });

  it('returns instagram-specific image limits', () => {
    expect(getMediaLimits('instagram').maxImages).toBe(10);
  });
});
