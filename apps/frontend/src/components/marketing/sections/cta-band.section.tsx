import Link from 'next/link';

export const CtaBandSection = () => {
  return (
    <section className="max-w-[1200px] w-full mx-auto px-[24px] pb-[80px]">
      <div
        className="rounded-[24px] px-[24px] py-[48px] sm:px-[64px] sm:py-[64px] text-center flex flex-col items-center gap-[16px] border border-white/5"
        style={{
          background: 'linear-gradient(135deg, #10b98126, #6366f126)',
        }}
      >
        <h2 className="text-[26px] sm:text-[36px] font-[700] tracking-[-0.02em] max-w-[560px]">
          Start free — 3 months of Standard on us
        </h2>
        <p className="text-[15px] text-white/70 max-w-[480px]">
          Every new account gets 3 months of the Standard plan automatically.
          No credit card required, cancel any time.
        </p>
        <Link
          href="/auth"
          className="inline-flex items-center justify-center h-[52px] px-[32px] rounded-[10px] font-[600] text-white text-[16px] bg-[#10b981] hover:bg-[#0da271] transition-colors mt-[8px]"
        >
          Start free
        </Link>
      </div>
    </section>
  );
};
