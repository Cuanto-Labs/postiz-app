import Link from 'next/link';
import { Campaign } from '@gitroom/frontend/components/landing/campaigns';
import { LogoTextComponent } from '@gitroom/frontend/components/ui/logo-text.component';

/**
 * Presentation only. The one thing that has to be right is the CTA target —
 * /auth?invite=<code> is what carries the campaign through to registration.
 */
export const LandingPage = ({ campaign }: { campaign: Campaign }) => {
  const registerHref = `/auth?invite=${encodeURIComponent(campaign.invite)}`;

  return (
    <div className="min-h-screen w-screen bg-[#0E0E0E] text-white flex flex-col">
      <header className="flex items-center justify-between px-[24px] py-[20px] max-w-[1200px] w-full mx-auto">
        <LogoTextComponent />
        <Link
          href="/auth/login"
          className="text-[14px] text-white/70 hover:text-white"
        >
          Log in
        </Link>
      </header>

      <main className="flex-1 flex items-center">
        <div className="max-w-[1200px] w-full mx-auto px-[24px] grid lg:grid-cols-2 gap-[48px] items-center py-[40px]">
          <div className="flex flex-col gap-[24px]">
            <div
              className="inline-flex self-start items-center gap-[8px] text-[13px] font-[600] rounded-full px-[12px] py-[6px]"
              style={{
                color: campaign.accent,
                background: `${campaign.accent}1a`,
              }}
            >
              {campaign.eyebrow}
            </div>

            <h1 className="text-[40px] lg:text-[56px] leading-[1.05] font-[700] tracking-[-0.02em]">
              {campaign.headline}
              <br />
              <span style={{ color: campaign.accent }}>
                {campaign.accentWord}
              </span>
            </h1>

            <p className="text-[18px] text-white/70 max-w-[480px]">
              {campaign.subhead}
            </p>

            <ul className="flex flex-col gap-[12px] mt-[8px]">
              {campaign.bullets.map((bullet) => (
                <li key={bullet} className="flex items-center gap-[12px]">
                  <span
                    className="min-w-[22px] h-[22px] rounded-full flex items-center justify-center"
                    style={{ background: `${campaign.accent}26` }}
                  >
                    <svg
                      width="12"
                      height="12"
                      viewBox="0 0 12 12"
                      fill="none"
                      aria-hidden="true"
                    >
                      <path
                        d="M2.5 6.2 5 8.5 9.5 3.5"
                        stroke={campaign.accent}
                        strokeWidth="1.8"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                  </span>
                  <span className="text-[15px] text-white/85">{bullet}</span>
                </li>
              ))}
            </ul>

            <div className="flex flex-wrap items-center gap-[16px] mt-[16px]">
              <Link
                href={registerHref}
                className="inline-flex items-center justify-center h-[52px] px-[28px] rounded-[10px] font-[600] text-white text-[16px]"
                style={{ background: campaign.accent }}
              >
                {campaign.cta}
              </Link>
              <span className="text-[13px] text-white/50">
                No credit card required
              </span>
            </div>
          </div>

          {/* Preview card — echoes the app's Post Preview so the pitch shows the
              product, not a stock illustration. */}
          <div className="hidden lg:block">
            <div className="bg-[#1A1919] rounded-[16px] p-[24px] border border-white/5">
              <div className="flex items-center gap-[10px] mb-[16px]">
                <div className="w-[40px] h-[40px] rounded-full bg-white/10" />
                <div className="flex flex-col">
                  <div className="text-[15px] font-[700]">Your brand</div>
                  <div className="text-[13px] text-white/50">
                    scheduled · in 2 hours
                  </div>
                </div>
              </div>
              <div className="text-[15px] text-white/85 leading-[1.5]">
                Launching something new this week — here is the behind the
                scenes. Drafted in seconds, scheduled across every channel. ✨
              </div>
              <div
                className="mt-[16px] rounded-[12px] h-[180px] w-full flex items-center justify-center"
                style={{
                  background: `linear-gradient(135deg, ${campaign.accent}33, #6366f133)`,
                }}
              >
                <span className="text-[13px] text-white/60">
                  AI-generated image
                </span>
              </div>
              <div className="flex gap-[8px] mt-[16px]">
                {['in', 'x', 'ig', 'fb'].map((channel) => (
                  <div
                    key={channel}
                    className="w-[28px] h-[28px] rounded-full bg-white/10 flex items-center justify-center text-[11px] text-white/60 uppercase"
                  >
                    {channel}
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </main>

      <footer className="max-w-[1200px] w-full mx-auto px-[24px] py-[24px] text-[13px] text-white/40 flex flex-wrap gap-[16px]">
        <Link href="/terms" className="hover:text-white/70">
          Terms
        </Link>
        <Link href="/privacy" className="hover:text-white/70">
          Privacy
        </Link>
        <span>© Cuanto Labs</span>
      </footer>
    </div>
  );
};
