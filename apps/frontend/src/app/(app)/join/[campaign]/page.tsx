import { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { isGeneralServerSide } from '@gitroom/helpers/utils/is.general.server.side';
import {
  CAMPAIGNS,
  getCampaign,
} from '@gitroom/frontend/components/landing/campaigns';
import { LandingPage } from '@gitroom/frontend/components/landing/landing.page';
import { MarketingNavComponent } from '@gitroom/frontend/components/marketing/marketing-nav.component';
import { MarketingFooterComponent } from '@gitroom/frontend/components/marketing/marketing-footer.component';

export const dynamic = 'force-dynamic';

// Pre-render the known campaign slugs; anything else 404s via notFound() below.
export function generateStaticParams() {
  return Object.keys(CAMPAIGNS).map((campaign) => ({ campaign }));
}

export async function generateMetadata(props: {
  params: Promise<{ campaign: string }>;
}): Promise<Metadata> {
  const { campaign: slug } = await props.params;
  const campaign = getCampaign(slug);
  const brand = isGeneralServerSide() ? 'Cuanto Socials' : 'Gitroom';
  if (!campaign) {
    return { title: brand };
  }
  return {
    title: `${campaign.headline} ${campaign.accentWord} — ${brand}`,
    description: campaign.subhead,
  };
}

export default async function JoinCampaign(props: {
  params: Promise<{ campaign: string }>;
}) {
  const { campaign: slug } = await props.params;
  const campaign = getCampaign(slug);

  if (!campaign) {
    notFound();
  }

  // LandingPage owns its own full-viewport layout (own header/CTA/footer) and
  // the invite-code flow lives entirely inside it — wrap, don't rewrite, so
  // that flow keeps working exactly as-is. The shared marketing nav/footer
  // are added around it purely for shell consistency with the rest of the
  // public site.
  return (
    <>
      <MarketingNavComponent />
      <LandingPage campaign={campaign} />
      <MarketingFooterComponent />
    </>
  );
}
