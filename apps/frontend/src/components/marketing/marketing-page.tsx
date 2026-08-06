import { MarketingNavComponent } from '@gitroom/frontend/components/marketing/marketing-nav.component';
import { MarketingFooterComponent } from '@gitroom/frontend/components/marketing/marketing-footer.component';
import { HeroSection } from '@gitroom/frontend/components/marketing/sections/hero.section';
import { SocialProofSection } from '@gitroom/frontend/components/marketing/sections/social-proof.section';
import { FeaturesSection } from '@gitroom/frontend/components/marketing/sections/features.section';
import { HowItWorksSection } from '@gitroom/frontend/components/marketing/sections/how-it-works.section';
import { AudienceSplitSection } from '@gitroom/frontend/components/marketing/sections/audience-split.section';
import { CtaBandSection } from '@gitroom/frontend/components/marketing/sections/cta-band.section';

/**
 * Public marketing landing page — served to logged-out visitors at `/`
 * (rewritten to /home by the proxy) and reachable directly at /home.
 * Presentation only; every CTA points at /auth or /pricing.
 */
export const MarketingPage = () => {
  return (
    <div className="min-h-screen w-screen bg-[#0E0E0E] text-white flex flex-col">
      <MarketingNavComponent />
      <main className="flex-1 flex flex-col">
        <HeroSection />
        <SocialProofSection />
        <FeaturesSection />
        <HowItWorksSection />
        <AudienceSplitSection />
        <CtaBandSection />
      </main>
      <MarketingFooterComponent />
    </div>
  );
};
