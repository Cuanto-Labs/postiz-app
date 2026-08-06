import { MarketingNavComponent } from '@gitroom/frontend/components/marketing/marketing-nav.component';
import { MarketingFooterComponent } from '@gitroom/frontend/components/marketing/marketing-footer.component';
import { PricingTiersSection } from '@gitroom/frontend/components/marketing/pricing/pricing-tiers.section';
import { PricingFaqSection } from '@gitroom/frontend/components/marketing/pricing/pricing-faq.section';

/**
 * Public /pricing page. Every price and per-tier limit shown comes from the
 * `pricing` source of truth (libraries/nestjs-libraries/.../subscriptions/pricing.ts)
 * via pricing-tiers.section — nothing is hardcoded here. FREE is skipped
 * from the grid since it isn't a sellable plan; new signups instead get a
 * timed Standard trial, called out in the note below the headline.
 */
export const PricingPage = () => {
  return (
    <div className="min-h-screen w-screen bg-[#0E0E0E] text-white flex flex-col">
      <MarketingNavComponent />
      <main className="flex-1 flex flex-col">
        <section className="max-w-[800px] w-full mx-auto px-[24px] pt-[64px] pb-[40px] text-center flex flex-col items-center gap-[16px]">
          <h1 className="text-[36px] sm:text-[48px] font-[700] tracking-[-0.02em]">
            Simple, transparent pricing
          </h1>
          <p className="text-[16px] sm:text-[18px] text-white/60 max-w-[560px]">
            Pick a plan that scales with your channels, your AI usage, and
            your team — upgrade, downgrade, or switch billing periods
            anytime.
          </p>
          <div className="mt-[8px] inline-flex items-center gap-[8px] text-[13px] font-[600] rounded-full px-[16px] py-[8px] text-[#10b981] bg-[#10b98120]">
            New sign-ups get a free 3-month trial of the Standard plan
          </div>
        </section>
        <PricingTiersSection />
        <PricingFaqSection />
      </main>
      <MarketingFooterComponent />
    </div>
  );
};
