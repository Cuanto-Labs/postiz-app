export const dynamic = 'force-dynamic';
import { AdminTierComponent } from '@gitroom/frontend/components/admin/admin-tier.component';
import { Metadata } from 'next';
import { isGeneralServerSide } from '@gitroom/helpers/utils/is.general.server.side';

export const metadata: Metadata = {
  title: `${isGeneralServerSide() ? 'Cuanto Socials' : 'Gitroom'} Plan Changes`,
  description: '',
};

export default async function Page() {
  return (
    <div className="bg-newBgColorInner flex-1 flex-col flex p-[20px] gap-[12px]">
      <AdminTierComponent />
    </div>
  );
}
