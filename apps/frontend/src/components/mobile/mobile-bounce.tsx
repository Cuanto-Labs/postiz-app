'use client';

import { FC, useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import { Logo } from '@gitroom/frontend/components/new-layout/logo';

// iOS registers this custom scheme (see ios/Sources/Core/Shared/AppIdentifiers.swift)
// and opens these `/m/*` pages inside an ASWebAuthenticationSession. Once the
// web-based OAuth flow lands here, we immediately bounce back into the app by
// navigating to the matching deep link with all query params preserved, which
// is what the session is watching for to complete the handoff.
const APP_URL_SCHEME = 'cuantosocials';

export const MobileBounce: FC<{ deepLinkPath: string }> = ({
  deepLinkPath,
}) => {
  const searchParams = useSearchParams();

  const qs = searchParams.toString();
  const deepLink = `${APP_URL_SCHEME}://${deepLinkPath}${qs ? `?${qs}` : ''}`;

  useEffect(() => {
    window.location.replace(deepLink);
  }, [deepLink]);

  return (
    <div className="flex flex-1 items-center justify-center text-white relative overflow-hidden min-h-[100vh]">
      <div className="absolute inset-0 opacity-30">
        <div className="absolute top-[20%] left-[10%] w-[300px] h-[300px] bg-[#10b981] rounded-full blur-[120px]" />
        <div className="absolute bottom-[20%] right-[10%] w-[250px] h-[250px] bg-[#10b981] rounded-full blur-[120px]" />
      </div>
      <div className="relative z-10 text-center">
        <div className="flex justify-center mb-[24px]">
          <Logo />
        </div>
        <div className="text-[16px] text-gray-400">
          Returning to the app...
        </div>
        <div className="mt-[32px] flex justify-center">
          <div className="w-[48px] h-[48px] border-[3px] border-[#10b981] border-t-transparent rounded-full animate-spin" />
        </div>
        <a
          href={deepLink}
          className="mt-[24px] inline-block text-[14px] text-[#10b981] underline"
        >
          Tap here if you're not redirected automatically
        </a>
      </div>
    </div>
  );
};
