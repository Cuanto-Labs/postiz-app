const STEPS = [
  {
    step: '01',
    title: 'Connect your channels',
    description:
      'Link LinkedIn, Instagram, X, TikTok, YouTube, and more in a few clicks.',
  },
  {
    step: '02',
    title: 'Generate with AI',
    description:
      'Draft posts, images, and video with AI — researched, on-brand, ready to edit.',
  },
  {
    step: '03',
    title: 'Schedule & analyze',
    description:
      'Queue across every channel on one calendar and track what is working.',
  },
];

export const HowItWorksSection = () => {
  return (
    <section className="max-w-[1200px] w-full mx-auto px-[24px] py-[80px]">
      <h2 className="text-center text-[28px] sm:text-[36px] font-[700] tracking-[-0.02em] mb-[48px]">
        How it works
      </h2>
      <div className="grid sm:grid-cols-3 gap-[32px]">
        {STEPS.map((item, index) => (
          <div key={item.step} className="flex flex-col gap-[12px]">
            <div className="flex items-center gap-[12px]">
              <span
                className="text-[14px] font-[700]"
                style={{ color: index % 2 === 0 ? '#10b981' : '#6366f1' }}
              >
                {item.step}
              </span>
              <div className="h-[1px] flex-1 bg-white/10" />
            </div>
            <h3 className="text-[18px] font-[600]">{item.title}</h3>
            <p className="text-[14px] text-white/60 leading-[1.5]">
              {item.description}
            </p>
          </div>
        ))}
      </div>
    </section>
  );
};
