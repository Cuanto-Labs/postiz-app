import Link from 'next/link';
import { LogoTextComponent } from '@gitroom/frontend/components/ui/logo-text.component';

/**
 * Marketing footer shell — reused across public pages (see marketing-nav
 * for the matching header shell).
 */
export const MarketingFooterComponent = () => {
  return (
    <footer className="border-t border-white/5">
      <div className="max-w-[1200px] w-full mx-auto px-[24px] py-[40px] flex flex-col sm:flex-row items-start sm:items-center justify-between gap-[24px]">
        <div className="text-white/60">
          <LogoTextComponent />
        </div>

        <div className="flex flex-wrap items-center gap-[16px] sm:gap-[24px] text-[13px] text-white/40">
          <Link href="/terms" className="hover:text-white/70">
            Terms
          </Link>
          <Link href="/privacy" className="hover:text-white/70">
            Privacy
          </Link>
          <a
            href="mailto:eliran@cuantolabs.com"
            className="hover:text-white/70"
          >
            eliran@cuantolabs.com
          </a>
          <span>© Cuanto Labs</span>
        </div>
      </div>
    </footer>
  );
};
