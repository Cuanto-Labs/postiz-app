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
  const title = `${campaign.headline} ${campaign.accentWord} — ${brand}`;
  return {
    title,
    description: campaign.subhead,
    openGraph: {
      title,
      description: campaign.subhead,
      url: `https://socials.cuantolabs.com/join/${campaign.slug}`,
      siteName: brand,
      type: 'website',
    },
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

  // LandingPage's invite-code CTA flow lives entirely inside it and is
  // untouched here — `chromeless` only drops its internal header/footer so
  // it sits cleanly inside the shared marketing nav/footer shell below.
  return (
    <>
      <MarketingNavComponent />
      <LandingPage campaign={campaign} chromeless />
      <MarketingFooterComponent />
    </>
  );
}
