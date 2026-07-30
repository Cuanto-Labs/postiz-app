import Link from 'next/link';

export const HeroSection = () => {
  return (
    <section className="max-w-[1200px] w-full mx-auto px-[24px] pt-[64px] pb-[72px] lg:pt-[104px] lg:pb-[96px] flex flex-col items-center text-center gap-[24px]">
      <div className="inline-flex items-center gap-[8px] text-[13px] font-[600] rounded-full px-[12px] py-[6px] text-[#10b981] bg-[#10b98120]">
        AI-powered social media management
      </div>

      <h1 className="text-[36px] sm:text-[48px] lg:text-[64px] leading-[1.08] font-[700] tracking-[-0.02em] max-w-[860px]">
        Plan, create, and publish everywhere{' '}
        <span
          className="bg-clip-text text-transparent"
          style={{
            backgroundImage: 'linear-gradient(90deg, #10b981, #6366f1)',
          }}
        >
          with AI that does the heavy lifting
        </span>
      </h1>

      <p className="text-[16px] sm:text-[18px] text-white/70 max-w-[640px]">
        Built for creators who want to move fast, and for agencies and teams
        running multiple brands at once — one workspace, every channel, AI
        drafting the first pass.
      </p>

      <div className="flex flex-wrap items-center justify-center gap-[16px] mt-[8px]">
        <Link
          href="/auth"
          className="inline-flex items-center justify-center h-[52px] px-[28px] rounded-[10px] font-[600] text-white text-[16px] bg-[#10b981] hover:bg-[#0da271] transition-colors"
        >
          Start free — 3 months of Standard on us
        </Link>
        <Link
          href="/pricing"
          className="inline-flex items-center justify-center h-[52px] px-[28px] rounded-[10px] font-[600] text-white text-[16px] border border-white/15 hover:bg-white/5 transition-colors"
        >
          See pricing
        </Link>
      </div>

      <span className="text-[13px] text-white/50">
        No credit card required
      </span>
    </section>
  );
};
