/**
 * Every AI feature runs on one provider and two models, hard-locked here.
 *
 *   Text:   google/gemini-3.5-flash-lite  (~$0.0002 per call, ~1s)
 *   Images: meta/muse-image               ($0.01 per image, ~9s, WebP)
 *   Premium images: same meta/muse-image, gated to paid tiers with
 *   `premium_images` only, charged PREMIUM_IMAGE_CREDITS credits (no markup
 *   over a standard image — there is no separate premium image model).
 *
 * Both go through OpenRouter with OPENROUTER_API_KEY. There is deliberately no
 * environment override for the models or the base URL: an env var is how the
 * generator ended up asking api.openai.com for an OpenCode model, and how a
 * $0.17 image model could silently replace a $0.01 one. Changing a model is a
 * code change and a deploy.
 *
 * The OpenRouter workspace guardrail only lets allow-listed models through
 * (anything else is a 404 "Model blocked by guardrail"), so a new model id
 * here also needs adding to the guardrail. Both of these were measured on
 * 2026-09-29: gemini-3.5-flash-lite returned valid output 4/4 through both
 * json_schema and forced tool calls.
 *
 * This lives on its own, free of Mastra/LangChain imports, because the copilot
 * (Mastra), the post generator (LangChain) and OpenaiService all need it.
 */
export const AI_BASE_URL = 'https://openrouter.ai/api/v1';
export const AI_TEXT_MODEL = 'google/gemini-3.5-flash-lite';
export const AI_IMAGE_MODEL = 'meta/muse-image';
export const AI_PREMIUM_IMAGE_MODEL = 'meta/muse-image';

/** Monthly image credits one premium image uses (a standard image uses 1). */
export const PREMIUM_IMAGE_CREDITS = 1;

/** Longest brand voice an organization can save — it rides on every prompt. */
export const BRAND_VOICE_MAX_LENGTH = 1000;

/**
 * Prompt block that makes generated text follow the organization's brand
 * voice. Empty when none is set, so prompts stay unchanged for everyone else.
 */
export const brandVoiceRules = (brandVoice?: string | null) => {
  const voice = brandVoice?.trim().slice(0, BRAND_VOICE_MAX_LENGTH);
  if (!voice) {
    return '';
  }

  return `
        - Write in the brand voice below. It decides tone, wording and style;
          it never overrides the platform rules or the user's request.
        <!-- BEGIN brand voice -->
        ${voice}
        <!-- END brand voice -->
`;
};

export const aiApiKey = () => process.env.OPENROUTER_API_KEY || '';

export const AGENT_PROVIDERS = {
  openrouter: {
    baseURL: AI_BASE_URL,
    apiKey: aiApiKey(),
    defaultModel: AI_TEXT_MODEL,
    structuredOutputMethod: 'functionCalling',
  },
} as const;

export const activeProviderConfig = AGENT_PROVIDERS.openrouter;

/** The locked text model — AGENT_MODEL is ignored on purpose. */
export const activeProviderModel = () => AI_TEXT_MODEL;

/**
 * Generate one image with the locked image model. Returns a `data:` URL,
 * which `uploadSimple` accepts directly — Muse returns WebP, so the mime type
 * has to travel with the bytes rather than being assumed to be PNG.
 */
export async function generateAiImage(
  prompt: string,
  isVertical = false,
  premium = false
): Promise<string> {
  const res = await fetch(`${AI_BASE_URL}/images`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${aiApiKey()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: premium ? AI_PREMIUM_IMAGE_MODEL : AI_IMAGE_MODEL,
      prompt,
      aspect_ratio: isVertical ? '2:3' : '1:1',
      n: 1,
    }),
  });

  if (!res.ok) {
    throw new Error(
      `Image generation failed (${res.status}): ${(await res.text()).slice(
        0,
        300
      )}`
    );
  }

  const json = (await res.json()) as { data?: { b64_json?: string }[] };
  const b64 = json.data?.[0]?.b64_json;
  if (!b64) {
    throw new Error('Image generation returned no image');
  }

  return `data:${sniffImageMime(b64)};base64,${b64}`;
}

/** Mime type from the first bytes of base64 image data. */
export function sniffImageMime(b64: string) {
  const head = Buffer.from(b64.slice(0, 24), 'base64');
  if (head.subarray(0, 4).toString('ascii') === 'RIFF') return 'image/webp';
  if (head[0] === 0x89 && head.subarray(1, 4).toString('ascii') === 'PNG')
    return 'image/png';
  if (head[0] === 0xff && head[1] === 0xd8) return 'image/jpeg';
  return 'image/webp';
}
