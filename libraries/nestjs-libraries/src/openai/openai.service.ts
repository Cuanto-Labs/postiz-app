import { Injectable } from '@nestjs/common';
import OpenAI from 'openai';
import { shuffle } from 'lodash';
import { zodResponseFormat } from 'openai/helpers/zod';
import { z } from 'zod';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY || 'sk-proj-',
});

// Text generation may run on a different OpenAI-compatible endpoint than image
// generation (images stay on OpenAI). Everything is env-driven so the provider
// and model never leak to a client.
const textModel = process.env.AI_TEXT_MODEL || 'gpt-4.1';
const textClient = process.env.AI_TEXT_API_KEY
  ? new OpenAI({
      apiKey: process.env.AI_TEXT_API_KEY,
      baseURL: process.env.AI_TEXT_BASE_URL || 'https://api.openai.com/v1',
    })
  : openai;

// Reasoning models spend their budget before emitting content; keep it low so a
// suggestion request does not stall or bill for a hidden chain of thought.
const textExtra: Record<string, any> = process.env.AI_TEXT_REASONING_EFFORT
  ? { reasoning: { effort: process.env.AI_TEXT_REASONING_EFFORT } }
  : {};

// `n` is an OpenAI-only parameter; other providers silently return one choice.
// Fan out the remainder so the caller always gets the variation count it asked for.
async function chatChoices(params: any, n: number) {
  const first = await textClient.chat.completions.create({
    ...params,
    ...textExtra,
    n,
  });

  const choices = [...first.choices];
  if (choices.length >= n) {
    return choices;
  }

  const rest = await Promise.all(
    Array.from({ length: n - choices.length }, () =>
      textClient.chat.completions.create({ ...params, ...textExtra })
    )
  );

  return [...choices, ...rest.flatMap((r: any) => r.choices)];
}

const PicturePrompt = z.object({
  prompt: z.string(),
});

const VoicePrompt = z.object({
  voice: z.string(),
});

@Injectable()
export class OpenaiService {
  async generateImage(prompt: string, isVertical = false) {
    // gpt-image models always return base64 (b64_json) and do not accept the
    // `response_format` parameter, unlike the deprecated dall-e-3.
    const generate = (
      await openai.images.generate({
        prompt,
        model: 'gpt-image-1',
        size: isVertical ? '1024x1536' : '1024x1024',
      })
    ).data[0];

    return generate.b64_json;
  }

  async generatePromptForPicture(prompt: string) {
    return (
      (
        await textClient.chat.completions.parse({
          model: textModel,
          messages: [
            {
              role: 'system',
              content: `You are an assistant that take a description and style and generate a prompt that will be used later to generate images, make it a very long and descriptive explanation, and write a lot of things for the renderer like, if it${"'"}s realistic describe the camera`,
            },
            {
              role: 'user',
              content: `prompt: ${prompt}`,
            },
          ],
          response_format: zodResponseFormat(PicturePrompt, 'picturePrompt'),
        })
      ).choices[0].message.parsed?.prompt || ''
    );
  }

  async generateVoiceFromText(prompt: string) {
    return (
      (
        await textClient.chat.completions.parse({
          model: textModel,
          messages: [
            {
              role: 'system',
              content: `You are an assistant that takes a social media post and convert it to a normal human voice, to be later added to a character, when a person talk they don\'t use "-", and sometimes they add pause with "..." to make it sounds more natural, make sure you use a lot of pauses and make it sound like a real person`,
            },
            {
              role: 'user',
              content: `prompt: ${prompt}`,
            },
          ],
          response_format: zodResponseFormat(VoicePrompt, 'voice'),
        })
      ).choices[0].message.parsed?.voice || ''
    );
  }

  async generatePosts(content: string) {
    const [singles, threads] = await Promise.all([
      chatChoices(
        {
          messages: [
            {
              role: 'assistant',
              content:
                'Generate a Twitter post from the content without emojis in the following JSON format: { "post": string } put it in an array with one element',
            },
            {
              role: 'user',
              content: content!,
            },
          ],
          temperature: 1,
          model: textModel,
        },
        5
      ),
      chatChoices(
        {
          messages: [
            {
              role: 'assistant',
              content:
                'Generate a thread for social media in the following JSON format: Array<{ "post": string }> without emojis',
            },
            {
              role: 'user',
              content: content!,
            },
          ],
          temperature: 1,
          model: textModel,
        },
        5
      ),
    ]);

    // One choice is one suggestion: a single post, or a thread flattened into a
    // single string. Callers expect strings, not the raw JSON the model emits.
    return shuffle(
      [...singles, ...threads]
        .map((choice: any) => {
          const raw = choice.message?.content as string | null | undefined;
          if (!raw) {
            return '';
          }

          const start = raw.indexOf('[');
          const end = raw.lastIndexOf(']');

          try {
            const parsed = JSON.parse(
              '[' +
                raw
                  .slice(start + 1, end)
                  .replace(/\n/g, ' ')
                  .replace(/ {2,}/g, ' ') +
                ']'
            );

            return parsed
              .map((entry: any) =>
                typeof entry === 'string' ? entry : entry?.post ?? ''
              )
              .filter(Boolean)
              .join('\n\n');
          } catch (e) {
            return '';
          }
        })
        .filter(Boolean)
    );
  }

  async extractWebsiteText(content: string) {
    const websiteContent = await textClient.chat.completions.create({
      messages: [
        {
          role: 'assistant',
          content:
            'You take a full website text, and extract only the article content',
        },
        {
          role: 'user',
          content,
        },
      ],
      model: textModel,
    });

    const { content: articleContent } = websiteContent.choices[0].message;

    return this.generatePosts(articleContent!);
  }

  async separatePosts(content: string, len: number) {
    const SeparatePostsPrompt = z.object({
      posts: z.array(z.string()),
    });

    const SeparatePostPrompt = z.object({
      post: z.string().max(len),
    });

    const posts =
      (
        await textClient.chat.completions.parse({
          model: textModel,
          messages: [
            {
              role: 'system',
              content: `You are an assistant that take a social media post and break it to a thread, each post must be minimum ${
                len - 10
              } and maximum ${len} characters, keeping the exact wording and break lines, however make sure you split posts based on context`,
            },
            {
              role: 'user',
              content: content,
            },
          ],
          response_format: zodResponseFormat(
            SeparatePostsPrompt,
            'separatePosts'
          ),
        })
      ).choices[0].message.parsed?.posts || [];

    return {
      posts: await Promise.all(
        posts.map(async (post: any) => {
          if (post.length <= len) {
            return post;
          }

          let retries = 4;
          while (retries) {
            try {
              return (
                (
                  await textClient.chat.completions.parse({
                    model: textModel,
                    messages: [
                      {
                        role: 'system',
                        content: `You are an assistant that take a social media post and shrink it to be maximum ${len} characters, keeping the exact wording and break lines`,
                      },
                      {
                        role: 'user',
                        content: post,
                      },
                    ],
                    response_format: zodResponseFormat(
                      SeparatePostPrompt,
                      'separatePost'
                    ),
                  })
                ).choices[0].message.parsed?.post || ''
              );
            } catch (e) {
              retries--;
            }
          }

          return post;
        })
      ),
    };
  }

  async generateSlidesFromText(text: string) {
    for (let i = 0; i < 3; i++) {
      try {
        const message = `You are an assistant that takes a text and break it into slides, each slide should have an image prompt and voice text to be later used to generate a video and voice, image prompt should capture the essence of the slide and also have a back dark gradient on top, image prompt should not contain text in the picture, generate between 3-5 slides maximum`;
        const parse =
          (
            await textClient.chat.completions.parse({
              model: textModel,
              messages: [
                {
                  role: 'system',
                  content: message,
                },
                {
                  role: 'user',
                  content: text,
                },
              ],
              response_format: zodResponseFormat(
                z.object({
                  slides: z
                    .array(
                      z.object({
                        imagePrompt: z.string(),
                        voiceText: z.string(),
                      })
                    )
                    .describe('an array of slides'),
                }),
                'slides'
              ),
            })
          ).choices[0].message.parsed?.slides || [];

        return parse;
      } catch (err) {
        console.log(err);
      }
    }

    return [];
  }
}
