export const dynamic = 'force-dynamic';
import { AdminCodesComponent } from '@gitroom/frontend/components/admin/admin-codes.component';
import { Metadata } from 'next';
import { isGeneralServerSide } from '@gitroom/helpers/utils/is.general.server.side';

export const metadata: Metadata = {
  title: `${isGeneralServerSide() ? 'Cuanto Socials' : 'Gitroom'} Invite Codes`,
  description: '',
};

export default async function Page() {
  return (
    <div className="bg-newBgColorInner flex-1 flex-col flex p-[20px] gap-[12px]">
      <AdminCodesComponent />
    </div>
  );
}
