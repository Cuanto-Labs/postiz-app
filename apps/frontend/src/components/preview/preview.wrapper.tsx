'use client';

import useSWR from 'swr';
import { ContextWrapper } from '@gitroom/frontend/components/layout/user.context';
import { ReactNode, useCallback, useEffect, useState } from 'react';
import { useFetch } from '@gitroom/helpers/utils/custom.fetch';
import { Toaster } from '@gitroom/react/toaster/toaster';
import { MantineWrapper } from '@gitroom/react/helpers/mantine.wrapper';
import { useVariables } from '@gitroom/react/helpers/variable.context';
import { CopilotKit } from '@copilotkit/react-core';
import { ToolTip } from '@gitroom/frontend/components/layout/top.tip';
export const PreviewWrapper = ({ children }: { children: ReactNode }) => {
  const fetch = useFetch();
  const { backendUrl } = useVariables();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  const load = useCallback(async (path: string) => {
    return await (await fetch(path)).json();
  }, []);
  const { data: user } = useSWR('/user/self', load, {
    revalidateOnFocus: false,
    revalidateOnReconnect: false,
    revalidateIfStale: false,
    refreshWhenOffline: false,
    refreshWhenHidden: false,
  });
  const inner = (
    <ContextWrapper user={user}>
      <MantineWrapper>
        <Toaster />
        <ToolTip />
        {children}
      </MantineWrapper>
    </ContextWrapper>
  );
  // CopilotKit needs a valid absolute runtimeUrl; rendering it during SSR
  // (or with an empty/relative backendUrl) throws and 500s the preview.
  // Mount it client-side only, and only when backendUrl is present.
  if (!mounted || !backendUrl) {
    return inner;
  }
  return (
    <CopilotKit
      credentials="include"
      runtimeUrl={backendUrl + '/copilot/chat'}
      showDevConsole={false}
    >
      {inner}
    </CopilotKit>
  );
};
