type Feature = {
  title: string;
  description: string;
  accent: string;
  path: string;
};

// Icons are single-path line glyphs (24x24 viewBox, stroke=currentColor) so
// they inherit the card's accent color without extra markup.
const FEATURES: Feature[] = [
  {
    title: 'AI post generator with live web research',
    description:
      'AI drafts on-brand posts backed by live web research, not stale training data — ready to review and send.',
    accent: '#10b981',
    path: 'M11 2a9 9 0 1 0 5.6 16.1M21 21l-4.35-4.35M11 6a5 5 0 0 1 5 5M11 2v4M15 4l-2 2',
  },
  {
    title: 'AI Copilot chat assistant',
    description:
      'Chat with an AI copilot that plans campaigns, drafts posts, and answers questions about your calendar.',
    accent: '#6366f1',
    path: 'M21 11.5a8.38 8.38 0 0 1-4.8 7.6A8.5 8.5 0 0 1 3 12.5 8.38 8.38 0 0 1 11.5 3a8.5 8.5 0 0 1 9.5 8.5Z M8 10h.01M12 10h.01M16 10h.01',
  },
  {
    title: 'AI image generation + design editor',
    description:
      'Generate on-brand images with AI, then fine-tune every detail in the built-in design editor.',
    accent: '#10b981',
    path: 'M3 5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5Z M8.5 10a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z M21 15l-5-5L5 21',
  },
  {
    title: 'AI video generation, voiceover + subtitles',
    description:
      'Turn a prompt into a finished video — with AI voiceover and auto-generated subtitles baked in.',
    accent: '#6366f1',
    path: 'M15 10l5-3v10l-5-3M3 6h11a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1Z',
  },
  {
    title: 'Cross-channel scheduling calendar',
    description:
      'Plan and queue posts for every channel on one shared calendar — see the whole week at a glance.',
    accent: '#10b981',
    path: 'M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z',
  },
  {
    title: 'Analytics',
    description:
      'Track reach, engagement, and growth across every connected channel from one dashboard.',
    accent: '#6366f1',
    path: 'M3 3v18h18M8 17V10M13 17V6M18 17v-4',
  },
  {
    title: 'Team workspaces & roles',
    description:
      'Invite your team, assign roles, and manage every client or brand from one shared workspace.',
    accent: '#10b981',
    path: 'M17 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M11 3a4 4 0 1 1 0 8 4 4 0 0 1 0-8ZM22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75',
  },
  {
    title: 'Public API + MCP server',
    description:
      'Automate publishing from your own tools with a public API and a native MCP server.',
    accent: '#6366f1',
    path: 'M16 18l6-6-6-6M8 6l-6 6 6 6',
  },
];

export const FeaturesSection = () => {
  return (
    <section id="features" className="max-w-[1200px] w-full mx-auto px-[24px] py-[80px] scroll-mt-[80px]">
      <div className="text-center max-w-[640px] mx-auto mb-[48px]">
        <h2 className="text-[28px] sm:text-[36px] font-[700] tracking-[-0.02em] mb-[12px]">
          Everything you need to run social, in one place
        </h2>
        <p className="text-[15px] text-white/60">
          From the first draft to the published post — AI handles the heavy
          lifting, you stay in control.
        </p>
      </div>

      <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-[20px]">
        {FEATURES.map((feature) => (
          <div
            key={feature.title}
            className="rounded-[16px] p-[24px] bg-[#1A1919] border border-white/5 flex flex-col gap-[16px]"
          >
            <span
              className="w-[40px] h-[40px] rounded-[10px] flex items-center justify-center"
              style={{ background: `${feature.accent}20`, color: feature.accent }}
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                aria-hidden="true"
              >
                <path
                  d={feature.path}
                  stroke="currentColor"
                  strokeWidth="1.6"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </span>
            <div className="flex flex-col gap-[6px]">
              <h3 className="text-[15px] font-[600]">{feature.title}</h3>
              <p className="text-[13px] text-white/60 leading-[1.5]">
                {feature.description}
              </p>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
};
