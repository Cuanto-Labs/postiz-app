import { ReactNode } from 'react';
import { PreviewWrapper } from '@gitroom/frontend/components/preview/preview.wrapper';
import { ErrorCatcher } from '@gitroom/frontend/components/preview/error.catcher';

export default async function AppLayout({ children }: { children: ReactNode }) {
  return (
    <div className="bg-[#000000] min-h-screen">
      <ErrorCatcher>
        <PreviewWrapper>{children}</PreviewWrapper>
      </ErrorCatcher>
    </div>
  );
}
