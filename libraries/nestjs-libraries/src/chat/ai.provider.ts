/**
 * Provider pool for the LLM-backed features — two named providers, selected
 * with AGENT_PROVIDER. Each carries its own base URL + API key so both can be
 * configured at once and swapped by changing one variable.
 *
 *   AGENT_PROVIDER = opencode (default) | openai
 *   AGENT_MODEL    = model name, must exist on the *active* provider
 *
 * OpenCode:  OPENCODE_BASE_URL (default https://opencode.ai/zen/v1) + OPENCODE_API_KEY
 * OpenAI:    OPENAI_BASE_URL   (default https://api.openai.com/v1)   + OPENAI_API_KEY
 *
 * This lives on its own, free of Mastra/LangChain imports, because both the
 * copilot (Mastra) and the post generator (LangChain) need it — and AGENT_MODEL
 * is meaningless without the base URL it belongs to. Reading the model name
 * without the matching provider is how the generator ended up asking
 * api.openai.com for an OpenCode model.
 *
 * Picking the OpenCode default is narrower than "a model that exists". The
 * generator drives `withStructuredOutput()`, and most of the free pool rejects
 * the schema request even when plain chat and raw tool calls succeed. Measured
 * against the real endpoint: deepseek-v4-flash-free fails every method,
 * nemotron-3-ultra-free works but spends ~116s on the content step, and
 * ling-3.0-flash-free returns in ~6s for three steps — matching gpt-4.1 — but
 * only when the structured call is forced down the functionCalling path. Hence
 * `structuredOutputMethod`, which travels with the provider rather than being
 * hardcoded at each call site. Re-measure before changing either field.
 *
 * These are free models on a free gateway and they do disappear: the previous
 * default, mimo-v2.5-free, still lists in /models but returns 500 on every
 * request. If the generator or copilot starts failing, set AGENT_PROVIDER=openai
 * to move both onto the paid account without a deploy.
 */
export const AGENT_PROVIDERS = {
  opencode: {
    baseURL: process.env.OPENCODE_BASE_URL || 'https://opencode.ai/zen/v1',
    apiKey: process.env.OPENCODE_API_KEY || '',
    defaultModel: 'ling-3.0-flash-free',
    structuredOutputMethod: 'functionCalling',
  },
  openai: {
    baseURL: process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1',
    apiKey: process.env.OPENAI_API_KEY || '',
    defaultModel: 'gpt-4o',
    structuredOutputMethod: 'jsonSchema',
  },
} as const;

const activeProviderKey = (process.env.AGENT_PROVIDER ||
  'opencode') as keyof typeof AGENT_PROVIDERS;

export const activeProviderConfig =
  AGENT_PROVIDERS[activeProviderKey] ?? AGENT_PROVIDERS.opencode;

/** Model for the active provider — never mix this with another provider's URL. */
export const activeProviderModel = () =>
  process.env.AGENT_MODEL || activeProviderConfig.defaultModel;
