import { MobileAiService } from './mobile-ai.service';

function makeDeps() {
  const aiConsentRepository = {
    getConsentAt: jest.fn(),
    setConsent: jest.fn(),
  };
  const openaiService = {
    generatePosts: jest.fn(),
    separatePosts: jest.fn(),
  };

  const service = new MobileAiService(
    aiConsentRepository as any,
    openaiService as any
  );

  return { service, aiConsentRepository, openaiService };
}

describe('MobileAiService', () => {
  const OLD_ENV = process.env;

  beforeEach(() => {
    process.env = { ...OLD_ENV };
  });

  afterAll(() => {
    process.env = OLD_ENV;
  });

  it('throws 403 and never calls OpenAI when consent is not granted', async () => {
    process.env.OPENROUTER_API_KEY = 'sk-test';
    const { service, aiConsentRepository, openaiService } = makeDeps();
    aiConsentRepository.getConsentAt.mockResolvedValue(null);

    await expect(
      service.suggest('user1', { content: 'hello', mode: 'variations' })
    ).rejects.toMatchObject({
      response: { msg: 'AI consent required' },
      status: 403,
    });

    expect(openaiService.generatePosts).not.toHaveBeenCalled();
    expect(openaiService.separatePosts).not.toHaveBeenCalled();
  });

  it('calls generatePosts when consent granted and mode is variations', async () => {
    process.env.OPENROUTER_API_KEY = 'sk-test';
    const { service, aiConsentRepository, openaiService } = makeDeps();
    aiConsentRepository.getConsentAt.mockResolvedValue(new Date());
    openaiService.generatePosts.mockResolvedValue([{ post: 'a' }, 'b']);

    const result = await service.suggest('user1', {
      content: 'hello',
      mode: 'variations',
    });

    expect(openaiService.generatePosts).toHaveBeenCalledWith('hello');
    expect(result).toEqual({ suggestions: ['a', 'b'] });
  });

  it('calls separatePosts when consent granted and mode is fit', async () => {
    process.env.OPENROUTER_API_KEY = 'sk-test';
    const { service, aiConsentRepository, openaiService } = makeDeps();
    aiConsentRepository.getConsentAt.mockResolvedValue(new Date());
    openaiService.separatePosts.mockResolvedValue(['fit-post']);

    const result = await service.suggest('user1', {
      content: 'hello',
      mode: 'fit',
      maxLength: 100,
    });

    expect(openaiService.separatePosts).toHaveBeenCalledWith('hello', 100);
    expect(result).toEqual({ suggestions: ['fit-post'] });
  });

  it('throws 503 when OPENROUTER_API_KEY is unset', async () => {
    delete process.env.OPENROUTER_API_KEY;
    const { service, aiConsentRepository, openaiService } = makeDeps();
    aiConsentRepository.getConsentAt.mockResolvedValue(new Date());

    await expect(
      service.suggest('user1', { content: 'hello', mode: 'variations' })
    ).rejects.toMatchObject({
      response: { msg: 'AI not configured' },
      status: 503,
    });

    expect(openaiService.generatePosts).not.toHaveBeenCalled();
  });

  it('flattens generatePosts threads and separatePosts envelopes', async () => {
    process.env.OPENROUTER_API_KEY = 'sk-test';
    const { service, aiConsentRepository, openaiService } = makeDeps();
    aiConsentRepository.getConsentAt.mockResolvedValue(new Date());
    openaiService.generatePosts.mockResolvedValue([
      'single post',
      [{ post: 'part one' }, { post: 'part two' }],
      { post: 'object post' },
      '',
    ]);

    const variations = await service.suggest('user-1', {
      content: 'hello',
      mode: 'variations',
    });
    expect(variations.suggestions).toEqual([
      'single post',
      'part one\n\npart two',
      'object post',
    ]);

    openaiService.separatePosts.mockResolvedValue({
      posts: ['first', 'second'],
    });
    const fit = await service.suggest('user-1', {
      content: 'hello',
      mode: 'fit',
      maxLength: 120,
    });
    expect(fit.suggestions).toEqual(['first', 'second']);
  });
});
