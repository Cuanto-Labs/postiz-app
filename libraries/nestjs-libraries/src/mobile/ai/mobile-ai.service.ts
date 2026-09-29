import { HttpException, Injectable } from '@nestjs/common';
import { AiConsentRepository } from '@gitroom/nestjs-libraries/mobile/ai/ai-consent.repository';
import { OpenaiService } from '@gitroom/nestjs-libraries/openai/openai.service';
import { aiApiKey } from '@gitroom/nestjs-libraries/chat/ai.provider';

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
    return !!aiApiKey();
  }

  async suggest(
    userId: string,
    {
      content,
      mode,
      maxLength,
    }: { content: string; mode: 'variations' | 'fit'; maxLength?: number },
    brandVoice?: string | null
  ): Promise<{ suggestions: string[] }> {
    await this.requireConsent(userId);

    if (!this.isConfigured()) {
      throw new HttpException({ msg: 'AI not configured' }, 503);
    }

    if (mode === 'variations') {
      const posts = await this._openaiService.generatePosts(
        content,
        brandVoice
      );
      return { suggestions: this.normalize(posts) };
    }

    const posts = await this._openaiService.separatePosts(
      content,
      maxLength ?? 280
    );
    return { suggestions: this.normalize(posts) };
  }

  private normalize(posts: unknown): string[] {
    // separatePosts answers with { posts }, generatePosts with a bare array.
    const list = Array.isArray(posts) ? posts : (posts as any)?.posts;
    if (!Array.isArray(list)) {
      return [];
    }

    // A provider can hand back a plain string, a { post } object, or a thread
    // as a nested array — flatten all three into one suggestion per entry.
    return list
      .map((post: any) => {
        if (typeof post === 'string') {
          return post;
        }

        if (Array.isArray(post)) {
          return post
            .map((entry: any) =>
              typeof entry === 'string' ? entry : entry?.post ?? ''
            )
            .filter(Boolean)
            .join('\n\n');
        }

        return post?.post ?? '';
      })
      .filter(Boolean);
  }
}
