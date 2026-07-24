import { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { isGeneralServerSide } from '@gitroom/helpers/utils/is.general.server.side';
import {
  CAMPAIGNS,
  getCampaign,
} from '@gitroom/frontend/components/landing/campaigns';
import { LandingPage } from '@gitroom/frontend/components/landing/landing.page';

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

  return <LandingPage campaign={campaign} />;
}
