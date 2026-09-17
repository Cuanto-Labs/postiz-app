import { HttpException, Injectable } from '@nestjs/common';
import { AiConsentRepository } from '@gitroom/nestjs-libraries/mobile/ai/ai-consent.repository';
import { OpenaiService } from '@gitroom/nestjs-libraries/openai/openai.service';

@Injectable()
export class MobileAiService {
  constructor(
    private _aiConsentRepository: AiConsentRepository,
    private _openaiService: OpenaiService
  ) {}

  async requireConsent(userId: string) {
    const consentAt = await this._aiConsentRepository.getConsentAt(userId);
    if (!consentAt) {
      throw new HttpException({ msg: 'AI consent required' }, 403);
    }
  }

  isConfigured() {
    return !!process.env.OPENAI_API_KEY;
  }

  async suggest(
    userId: string,
    {
      content,
      mode,
      maxLength,
    }: { content: string; mode: 'variations' | 'fit'; maxLength?: number }
  ): Promise<{ suggestions: string[] }> {
    await this.requireConsent(userId);

    if (!this.isConfigured()) {
      throw new HttpException({ msg: 'AI not configured' }, 503);
    }

    if (mode === 'variations') {
      const posts = await this._openaiService.generatePosts(content);
      return { suggestions: this.normalize(posts) };
    }

    const posts = await this._openaiService.separatePosts(
      content,
      maxLength ?? 280
    );
    return { suggestions: this.normalize(posts) };
  }

  private normalize(posts: unknown): string[] {
    if (!Array.isArray(posts)) {
      return [];
    }

    return posts.map((post) =>
      typeof post === 'string' ? post : post?.post ?? String(post)
    );
  }
}
