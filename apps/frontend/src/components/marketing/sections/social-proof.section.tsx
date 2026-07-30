const PLATFORMS: { name: string; icon: string }[] = [
  { name: 'LinkedIn', icon: 'linkedin' },
  { name: 'X', icon: 'x' },
  { name: 'Instagram', icon: 'instagram' },
  { name: 'Facebook', icon: 'facebook' },
  { name: 'TikTok', icon: 'tiktok' },
  { name: 'YouTube', icon: 'youtube' },
  { name: 'Reddit', icon: 'reddit' },
  { name: 'Discord', icon: 'discord' },
  { name: 'Mastodon', icon: 'mastodon' },
  { name: 'Pinterest', icon: 'pinterest' },
  { name: 'Threads', icon: 'threads' },
  { name: 'Slack', icon: 'slack' },
  { name: 'Telegram', icon: 'telegram' },
];

export const SocialProofSection = () => {
  return (
    <section className="border-y border-white/5 bg-white/[0.02]">
      <div className="max-w-[1200px] w-full mx-auto px-[24px] py-[32px]">
        <p className="text-center text-[12px] uppercase tracking-[0.08em] text-white/40 mb-[24px]">
          Publish everywhere your audience is — 28+ channels supported
        </p>
        <div className="flex flex-wrap items-center justify-center gap-x-[28px] gap-y-[16px]">
          {PLATFORMS.map((platform) => (
            <div
              key={platform.icon}
              className="flex items-center gap-[8px] text-white/60 hover:text-white/90 transition-colors"
            >
              <img
                src={`/icons/platforms/${platform.icon}.png`}
                alt={platform.name}
                className="w-[20px] h-[20px] rounded-[4px] opacity-90"
              />
              <span className="text-[13px]">{platform.name}</span>
            </div>
          ))}
          <span className="text-[13px] text-white/40">and more</span>
        </div>
      </div>
    </section>
  );
};
