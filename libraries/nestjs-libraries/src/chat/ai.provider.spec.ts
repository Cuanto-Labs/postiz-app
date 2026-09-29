import {
  AI_BASE_URL,
  AI_IMAGE_MODEL,
  AI_TEXT_MODEL,
  activeProviderConfig,
  activeProviderModel,
  generateAiImage,
  sniffImageMime,
} from '@gitroom/nestjs-libraries/chat/ai.provider';

// First bytes of a real Muse response: "RIFF....WEBP"
const WEBP_B64 = Buffer.from('RIFF\x10\x00\x00\x00WEBPVP8 ').toString('base64');
const PNG_B64 = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a]).toString(
  'base64'
);

describe('ai.provider (locked models)', () => {
  const realFetch = global.fetch;
  afterEach(() => {
    global.fetch = realFetch;
  });

  it('locks text to gemini-3.5-flash-lite and images to Muse on OpenRouter', () => {
    expect(AI_BASE_URL).toBe('https://openrouter.ai/api/v1');
    expect(AI_TEXT_MODEL).toBe('google/gemini-3.5-flash-lite');
    expect(AI_IMAGE_MODEL).toBe('meta/muse-image');
    expect(activeProviderConfig.baseURL).toBe(AI_BASE_URL);
  });

  it('ignores AGENT_MODEL', () => {
    process.env.AGENT_MODEL = 'gpt-4o';
    expect(activeProviderModel()).toBe(AI_TEXT_MODEL);
    delete process.env.AGENT_MODEL;
  });

  it('asks OpenRouter for one Muse image and returns a webp data URL', async () => {
    const fetchMock = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ data: [{ b64_json: WEBP_B64 }] }),
    });
    global.fetch = fetchMock as any;

    const out = await generateAiImage('a latte', true);

    expect(out).toBe(`data:image/webp;base64,${WEBP_B64}`);
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe('https://openrouter.ai/api/v1/images');
    expect(JSON.parse(init.body)).toEqual({
      model: 'meta/muse-image',
      prompt: 'a latte',
      aspect_ratio: '2:3',
      n: 1,
    });
  });

  it('throws on a provider error instead of returning an empty image', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 404,
      text: async () => 'Model blocked by guardrail',
    }) as any;

    await expect(generateAiImage('x')).rejects.toThrow(/404/);
  });

  it('throws when the response carries no image', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ data: [] }),
    }) as any;

    await expect(generateAiImage('x')).rejects.toThrow(/no image/);
  });

  it('sniffs the mime type from the bytes', () => {
    expect(sniffImageMime(WEBP_B64)).toBe('image/webp');
    expect(sniffImageMime(PNG_B64)).toBe('image/png');
  });
});
