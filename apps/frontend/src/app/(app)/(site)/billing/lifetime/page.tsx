// The lifetime-deal screen posted to POST /billing/lifetime, a route that never
// existed in this fork, so every claim failed. The URL is kept alive and now
// serves the generic redeem screen, which handles lifetime codes too.
import { RedeemCode } from '@gitroom/frontend/components/billing/redeem.code.component';
export const dynamic = 'force-dynamic';
import { Metadata } from 'next';
import { isGeneralServerSide } from '@gitroom/helpers/utils/is.general.server.side';
export const metadata: Metadata = {
  title: `${isGeneralServerSide() ? 'Cuanto Socials' : 'Gitroom'} Redeem a code`,
  description: '',
};
export default async function Page() {
  return <RedeemCode />;
}
