import Link from 'next/link';
import { LogoTextComponent } from '@gitroom/frontend/components/ui/logo-text.component';

/**
 * Sticky marketing nav shell — reused across the public landing page and any
 * future public pages (pricing, join campaigns) so the shell stays consistent.
 */
export const MarketingNavComponent = () => {
  return (
    <header className="sticky top-0 z-50 border-b border-white/5 bg-[#0E0E0E]/80 backdrop-blur">
      <div className="max-w-[1200px] w-full mx-auto px-[24px] py-[16px] flex items-center justify-between">
        <Link href="/home" aria-label="Cuanto Socials home" className="text-white">
          <LogoTextComponent />
        </Link>

        <nav className="hidden md:flex items-center gap-[32px] text-[14px] text-white/70">
          <Link href="#features" className="hover:text-white">
            Features
          </Link>
          <Link href="/pricing" className="hover:text-white">
            Pricing
          </Link>
          <Link href="/terms" className="hover:text-white">
            Terms
          </Link>
        </nav>

        <div className="flex items-center gap-[16px]">
          <Link
            href="/auth/login"
            className="hidden sm:inline-flex text-[14px] text-white/70 hover:text-white"
          >
            Log in
          </Link>
          <Link
            href="/auth"
            className="inline-flex items-center justify-center h-[40px] px-[20px] rounded-[10px] font-[600] text-white text-[14px] bg-[#10b981] hover:bg-[#0da271] transition-colors"
          >
            Start free
          </Link>
        </div>
      </div>
    </header>
  );
};
