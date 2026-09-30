import {
  AI_PREMIUM_IMAGE_MODEL,
  BRAND_VOICE_MAX_LENGTH,
  PREMIUM_IMAGE_CREDITS,
  brandVoiceRules,
  generateAiImage,
} from '@gitroom/nestjs-libraries/chat/ai.provider';

const WEBP_B64 = Buffer.from('RIFF\x10\x00\x00\x00WEBPVP8 ').toString('base64');

describe('brandVoiceRules', () => {
  it('adds nothing when the org has no brand voice', () => {
    expect(brandVoiceRules(undefined)).toBe('');
    expect(brandVoiceRules(null)).toBe('');
    expect(brandVoiceRules('   ')).toBe('');
  });

  it('wraps the brand voice and keeps the platform rules on top', () => {
    const rules = brandVoiceRules('  Friendly, no emojis  ');
    expect(rules).toContain(
      '<!-- BEGIN brand voice -->\n        Friendly, no emojis\n        <!-- END brand voice -->'
    );
    expect(rules).toContain('never overrides the platform rules');
  });

  it('caps the brand voice length', () => {
    const rules = brandVoiceRules('a'.repeat(BRAND_VOICE_MAX_LENGTH + 50));
    expect(rules).toContain('a'.repeat(BRAND_VOICE_MAX_LENGTH));
    expect(rules).not.toContain('a'.repeat(BRAND_VOICE_MAX_LENGTH + 1));
  });
});

describe('premium images', () => {
  const realFetch = global.fetch;
  afterEach(() => {
    global.fetch = realFetch;
  });

  it('costs 1 credit on meta/muse-image, same as a standard image', () => {
    expect(PREMIUM_IMAGE_CREDITS).toBe(1);
    expect(AI_PREMIUM_IMAGE_MODEL).toBe('meta/muse-image');
  });

  it('asks OpenRouter for the premium model when premium is set', async () => {
    const fetchMock = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ data: [{ b64_json: WEBP_B64 }] }),
    });
    global.fetch = fetchMock as any;

    await generateAiImage('a latte', false, true);

    expect(JSON.parse(fetchMock.mock.calls[0][1].body).model).toBe(
      AI_PREMIUM_IMAGE_MODEL
    );
  });
});
