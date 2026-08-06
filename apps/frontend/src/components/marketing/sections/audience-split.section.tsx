import Link from 'next/link';

type Audience = {
  eyebrow: string;
  title: string;
  accent: string;
  description: string;
  bullets: string[];
  cta: string;
  href: string;
};

const AUDIENCES: Audience[] = [
  {
    eyebrow: 'For creators',
    title: 'Grow your audience, on autopilot',
    accent: '#10b981',
    description:
      'AI drafts your posts and generates the images, you keep every channel on one calendar — built for creators who want to move fast and stay consistent.',
    bullets: [
      'AI writes posts and generates images for you',
      'Schedule ahead across every channel',
      'One calendar to plan and grow your audience',
    ],
    cta: 'Start creating free',
    href: '/join/creators',
  },
  {
    eyebrow: 'For agencies & teams',
    title: 'Run every client from one workspace',
    accent: '#6366f1',
    description:
      'Group channels by customer, invite your team with the right roles, and automate publishing with a public API and MCP server.',
    bullets: [
      'Multi-org workspaces with roles & permissions',
      'Group client channels together per customer',
      'Team invites, public API + MCP for automation',
    ],
    cta: 'Get started free',
    href: '/join/agencies',
  },
];

export const AudienceSplitSection = () => {
  return (
    <section className="max-w-[1200px] w-full mx-auto px-[24px] py-[80px]">
      <div className="text-center max-w-[640px] mx-auto mb-[48px]">
        <h2 className="text-[28px] sm:text-[36px] font-[700] tracking-[-0.02em] mb-[12px]">
          Built for how you actually work
        </h2>
        <p className="text-[15px] text-white/60">
          Whether you are a solo creator or running client accounts, pick the
          path that fits.
        </p>
      </div>

      <div className="grid sm:grid-cols-2 gap-[24px]">
        {AUDIENCES.map((audience) => (
          <div
            key={audience.href}
            className="rounded-[16px] p-[32px] bg-[#1A1919] border border-white/5 flex flex-col gap-[20px]"
          >
            <div
              className="inline-flex self-start items-center gap-[8px] text-[13px] font-[600] rounded-full px-[12px] py-[6px]"
              style={{ color: audience.accent, background: `${audience.accent}20` }}
            >
              {audience.eyebrow}
            </div>

            <h3 className="text-[22px] font-[700] tracking-[-0.01em]">
              {audience.title}
            </h3>
            <p className="text-[14px] text-white/60 leading-[1.5]">
              {audience.description}
            </p>

            <ul className="flex flex-col gap-[10px] mt-[4px]">
              {audience.bullets.map((bullet) => (
                <li key={bullet} className="flex items-center gap-[10px]">
                  <span
                    className="min-w-[20px] h-[20px] rounded-full flex items-center justify-center"
                    style={{ background: `${audience.accent}26` }}
                  >
                    <svg
                      width="11"
                      height="11"
                      viewBox="0 0 12 12"
                      fill="none"
                      aria-hidden="true"
                    >
                      <path
                        d="M2.5 6.2 5 8.5 9.5 3.5"
                        stroke={audience.accent}
                        strokeWidth="1.8"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                  </span>
                  <span className="text-[14px] text-white/80">{bullet}</span>
                </li>
              ))}
            </ul>

            <Link
              href={audience.href}
              className="inline-flex items-center justify-center h-[48px] px-[24px] rounded-[10px] font-[600] text-white text-[15px] mt-[8px] transition-opacity hover:opacity-90"
              style={{ background: audience.accent }}
            >
              {audience.cta}
            </Link>
          </div>
        ))}
      </div>
    </section>
  );
};
