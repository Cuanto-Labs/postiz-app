/**
 * /terms — Terms of Service for Cuanto Socials (web app + iOS app).
 *
 * Doubles as the EULA for the iOS app, so § "Apple App Store" must keep the
 * Apple-required terms (Apple is not a party, is a third-party beneficiary,
 * and handles support/refunds only through the App Store).
 */

import type { Metadata } from 'next';

const BRAND = {
  name: 'Cuanto Socials',
  url: 'https://socials.cuantolabs.com',
  supportEmail: 'eliran@cuantolabs.com',
  legal: {
    companyName: 'Cuanto Labs LLC',
    address: '18117 Biscayne Blvd, Suite 4537, Aventura, FL 33160, USA',
    jurisdiction: 'Florida, USA',
  },
};

const EFFECTIVE_DATE = 'September 17, 2026';

const TERMS_TITLE = `Terms of Service · ${BRAND.name}`;
const TERMS_DESCRIPTION = `Terms of Service for ${BRAND.name} — the web app and the iOS app, from ${BRAND.legal.companyName}.`;

export const metadata: Metadata = {
  title: TERMS_TITLE,
  description: TERMS_DESCRIPTION,
  robots: { index: true, follow: false },
  openGraph: {
    title: TERMS_TITLE,
    description: TERMS_DESCRIPTION,
    url: `${BRAND.url}/terms`,
    siteName: BRAND.name,
    type: 'website',
  },
};

export default function TermsPage() {
  const { name, url, supportEmail } = BRAND;
  const { companyName, address, jurisdiction } = BRAND.legal;

  return (
    <div className="mx-auto max-w-[720px] px-[16px] py-[64px] text-white">
      <h1 className="mb-[8px] font-bold text-[36px] tracking-tight">
        Terms of Service
      </h1>
      <p className="mb-[40px] text-white/60 text-[13px]">
        Effective date: {EFFECTIVE_DATE} &mdash; {companyName}
        {address ? `, ${address}` : ''}
      </p>

      <LegalSection title="1. Acceptance">
        <p>
          These Terms govern your use of {name} &mdash; the web app at{' '}
          <a href={url} className="underline underline-offset-2 hover:text-white">
            {url}
          </a>{' '}
          and the {name} app for iOS (together, the &ldquo;Service&rdquo;),
          operated by {companyName} (&ldquo;we,&rdquo; &ldquo;us,&rdquo; or
          &ldquo;our&rdquo;). By creating an account, signing in, or
          downloading the app you agree to them. If you do not agree, do not
          use the Service.
        </p>
        <p>
          We may update these Terms. Material changes get reasonable notice by
          email or an in-app banner, and continued use after that is
          acceptance.
        </p>
      </LegalSection>

      <LegalSection title="2. What the Service Does">
        <p>
          {name} schedules and publishes social media posts. You connect the
          accounts you already own, compose a post once, override it per
          channel where it matters, and queue it on a calendar. The iOS app is
          a client for the same workspace as the web app: it needs an existing{' '}
          {name} account, and everything it shows comes from that workspace.
        </p>
        <p>
          Supported networks change as platform APIs change. We may add,
          remove, or alter integrations and features; where a change removes
          something you rely on, we will give notice where practical.
        </p>
      </LegalSection>

      <LegalSection title="3. Accounts and Eligibility">
        <p>
          You must be at least 18, or the age of majority where you live, to
          hold an account. You are responsible for keeping your credentials
          confidential and for everything done under your account. Tell us
          promptly at{' '}
          <a
            href={`mailto:${supportEmail}`}
            className="underline underline-offset-2 hover:text-white"
          >
            {supportEmail}
          </a>{' '}
          if you believe it has been compromised.
        </p>
        <p>
          An organization may have several members. The account owner is
          responsible for its members&rsquo; activity and their compliance with
          these Terms.
        </p>
      </LegalSection>

      <LegalSection title="4. Connected Social Accounts">
        <p>
          Connecting a channel runs that network&rsquo;s own OAuth flow &mdash;
          for example X, LinkedIn, Facebook, Instagram, Threads, Mastodon,
          Bluesky, YouTube, TikTok, Pinterest, Reddit, Discord, Slack, or
          Telegram &mdash; and Sign in with Apple or Google may be used to sign
          in. You authorize us to act on the connected account only within the
          permissions you granted and only to provide the Service&rsquo;s
          scheduling, publishing, and analytics features.
        </p>
        <p>
          You must own or be authorized to manage every account you connect,
          and your use of each network remains subject to that network&rsquo;s
          own terms. If a network suspends, rate-limits, or changes its API, we
          may be unable to publish to it; that is outside our control.
        </p>
      </LegalSection>

      <LegalSection title="5. Your Content">
        <p>
          You keep ownership of everything you put into the Service &mdash;
          post text, images, video, and schedules (&ldquo;Your Content&rdquo;).
          You grant us a limited license to store, process, and transmit Your
          Content solely to run the Service, which includes publishing it to
          the channels you selected at the times you chose.
        </p>
        <p>
          You are responsible for Your Content, including that you hold the
          rights to any media you upload and that publishing it does not break
          the law or the rules of the network it is published to. Content
          produced with the optional AI features is Your Content too: review it
          before you schedule it.
        </p>
      </LegalSection>

      <LegalSection title="6. Pricing and Payment">
        <p>
          The iOS app is free and contains no in-app purchases, no
          subscriptions bought through the app, and no advertising. Where a
          paid plan exists, it is bought and billed on the web app, in advance,
          monthly or annually, through a third-party payment processor whose
          terms apply to your payment details.
        </p>
        <p>
          Fees are non-refundable except where the law requires otherwise. We
          may change pricing with 30 days&rsquo; notice; cancel before the
          change takes effect if you do not accept it.
        </p>
      </LegalSection>

      <LegalSection title="7. Acceptable Use">
        <p>You agree not to:</p>
        <ul className="mt-[8px] list-inside list-disc space-y-[4px]">
          <li>Break any applicable law or regulation.</li>
          <li>
            Publish spam, bulk unsolicited content, malware, or anything that
            violates a connected network&rsquo;s rules.
          </li>
          <li>
            Post content that infringes someone else&rsquo;s intellectual
            property, privacy, or publicity rights.
          </li>
          <li>Try to gain unauthorized access to any system, account, or data.</li>
          <li>Reverse-engineer, decompile, or disassemble the Service.</li>
          <li>Resell or sublicense the Service without written permission.</li>
          <li>
            Connect an account you do not own or are not authorized to manage.
          </li>
        </ul>
        <p>
          We may suspend or terminate an account that breaks these rules, with
          or without notice.
        </p>
      </LegalSection>

      <LegalSection title="8. Our Intellectual Property">
        <p>
          The Service itself &mdash; software, design, and branding, excluding
          Your Content &mdash; belongs to {companyName} and is protected by
          copyright, trademark, and other laws. You get a limited,
          non-exclusive, non-transferable, revocable license to use it for its
          intended purpose, and for the iOS app, to install and run it on
          Apple-branded devices you own or control, as permitted by the App
          Store Terms of Service.
        </p>
      </LegalSection>

      <LegalSection title="9. Apple App Store">
        <p>
          These Terms are between you and {companyName} only, not with Apple.
          Apple is not responsible for the iOS app or its content. Apple has no
          obligation to provide any support or maintenance for it &mdash;
          support requests go to{' '}
          <a
            href={`mailto:${supportEmail}`}
            className="underline underline-offset-2 hover:text-white"
          >
            {supportEmail}
          </a>
          . If the app fails to conform to any applicable warranty, you may
          notify Apple and Apple will refund the purchase price, if any; beyond
          that, Apple has no other warranty obligation. {companyName} is
          responsible for any claim that the app or your use of it infringes
          intellectual property rights, and for addressing any product
          liability, legal, or regulatory claim relating to the app. Apple and
          its subsidiaries are third-party beneficiaries of these Terms and may
          enforce them against you. You confirm you are not located in a
          country subject to a U.S. Government embargo or designated as
          terrorist-supporting, and are not on any U.S. Government list of
          prohibited or restricted parties.
        </p>
      </LegalSection>

      <LegalSection title="10. Privacy">
        <p>
          Our{' '}
          <a href="/privacy" className="underline underline-offset-2 hover:text-white">
            Privacy Policy
          </a>{' '}
          explains what the web app and the iOS app collect, why, and how to
          delete it. Using the Service means you accept it.
        </p>
      </LegalSection>

      <LegalSection title="11. Disclaimers">
        <p>
          THE SERVICE IS PROVIDED &ldquo;AS IS&rdquo; AND &ldquo;AS
          AVAILABLE&rdquo; WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED,
          INCLUDING WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
          PURPOSE, OR NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE SERVICE WILL
          BE UNINTERRUPTED OR ERROR-FREE, THAT EVERY SCHEDULED POST WILL BE
          ACCEPTED BY THE TARGET NETWORK, OR THAT CONNECTED NETWORKS WILL
          REMAIN AVAILABLE OR COMPATIBLE.
        </p>
      </LegalSection>

      <LegalSection title="12. Limitation of Liability">
        <p>
          TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW,{' '}
          {companyName.toUpperCase()}{' '}
          SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL,
          CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR LOSS OF PROFITS, REVENUE,
          DATA, OR GOODWILL, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
          DAMAGES.
        </p>
        <p>
          OUR TOTAL AGGREGATE LIABILITY FOR CLAIMS ARISING UNDER THESE TERMS
          SHALL NOT EXCEED THE GREATER OF (A) THE AMOUNTS YOU PAID US IN THE 12
          MONTHS PRECEDING THE CLAIM OR (B) USD 100.
        </p>
      </LegalSection>

      <LegalSection title="13. Indemnification">
        <p>
          You agree to indemnify and hold {companyName}, its affiliates,
          officers, directors, employees, and agents harmless from any claim,
          demand, loss, or damages (including reasonable attorneys&rsquo; fees)
          arising from Your Content, your use of the Service, or your breach of
          these Terms.
        </p>
      </LegalSection>

      <LegalSection title="14. Termination">
        <p>
          You may stop at any time by deleting your account from Settings in
          the app or from the web app; that disconnects your channels and
          removes your data as described in the Privacy Policy. We may
          terminate or suspend access for a breach of these Terms or where
          required by law. Posts already published to a network stay on that
          network &mdash; delete them there.
        </p>
      </LegalSection>

      <LegalSection title="15. Governing Law and Disputes">
        <p>
          These Terms are governed by the laws of {jurisdiction}, without
          regard to conflict-of-law principles. Disputes are resolved by
          binding arbitration in {jurisdiction}, except that either party may
          seek injunctive relief in a court of competent jurisdiction and you
          may bring a qualifying claim in small-claims court.
        </p>
      </LegalSection>

      <LegalSection title="16. Miscellaneous">
        <p>
          These Terms are the entire agreement between you and {companyName}{' '}
          about the Service. If a provision is unenforceable, the rest stands.
          Not enforcing a right is not a waiver of it. You may not assign these
          Terms without our written consent.
        </p>
      </LegalSection>

      <LegalSection title="17. Contact">
        <p>
          Questions about these Terms:{' '}
          <a
            href={`mailto:${supportEmail}`}
            className="underline underline-offset-2 hover:text-white"
          >
            {supportEmail}
          </a>
          {address ? <> or by mail at {companyName}, {address}.</> : null}
        </p>
      </LegalSection>
    </div>
  );
}

function LegalSection({
  title,
  children,
}: Readonly<{ title: string; children: React.ReactNode }>) {
  return (
    <section className="mb-[32px]">
      <h2 className="mb-[12px] font-semibold text-[20px]">{title}</h2>
      <div className="space-y-[12px] text-white/60 text-[13px] leading-relaxed">
        {children}
      </div>
    </section>
  );
}
