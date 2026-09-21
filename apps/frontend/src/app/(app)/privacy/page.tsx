/**
 * /privacy — Privacy Policy for Cuanto Socials (web app + iOS app).
 *
 * This is the URL filed as the Privacy Policy in the App Store listing, so it
 * must stay consistent with the App Privacy ("nutrition label") answers in
 * App Store Connect and with `ios/AppStore/metadata.md` § App Privacy. Change
 * one, change the others in the same pass.
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

const PRIVACY_TITLE = `Privacy Policy · ${BRAND.name}`;
const PRIVACY_DESCRIPTION = `Privacy Policy for ${BRAND.name} — what the web app and the iOS app collect, why, and how to delete it.`;

export const metadata: Metadata = {
  title: PRIVACY_TITLE,
  description: PRIVACY_DESCRIPTION,
  robots: { index: true, follow: false },
  openGraph: {
    title: PRIVACY_TITLE,
    description: PRIVACY_DESCRIPTION,
    url: `${BRAND.url}/privacy`,
    siteName: BRAND.name,
    type: 'website',
  },
};

export default function PrivacyPage() {
  const { name, url, supportEmail } = BRAND;
  const { companyName, address, jurisdiction } = BRAND.legal;

  return (
    <div className="mx-auto max-w-[720px] px-[16px] py-[64px] text-white">
      <h1 className="mb-[8px] font-bold text-[36px] tracking-tight">
        Privacy Policy
      </h1>
      <p className="mb-[40px] text-white/60 text-[13px]">
        Effective date: {EFFECTIVE_DATE} &mdash; {companyName}
        {address ? `, ${address}` : ''}
      </p>

      <LegalSection title="1. Scope — What This Covers">
        <p>
          {companyName}{' '}
          (&ldquo;we,&rdquo; &ldquo;us,&rdquo; or &ldquo;our&rdquo;) operates{' '}
          {name}: the web app at{' '}
          <a href={url} className="underline underline-offset-2 hover:text-white">
            {url}
          </a>{' '}
          and the {name} app for iOS (together, the
          &ldquo;Service&rdquo;). The iOS app is a client for the same
          workspace as the web app &mdash; it stores nothing on our servers
          that the web app does not, and it requires an existing{' '}
          {name} account.
        </p>
        <p>
          This policy does not cover the social networks you connect. Once a
          post is published to X, LinkedIn, Instagram, Facebook, Threads,
          Mastodon, Bluesky, YouTube, TikTok, Pinterest, Reddit, Discord,
          Slack, Telegram, or any other network you connect, that network&rsquo;s
          own privacy policy governs it.
        </p>
      </LegalSection>

      <LegalSection title="2. What We Collect">
        <p>
          <strong>Information you give us.</strong>
        </p>
        <ul className="mt-[8px] list-inside list-disc space-y-[4px]">
          <li>
            Account information &mdash; your email address, a password hash (or
            the identifier returned by Sign in with Apple or Google if you use
            those), and your display name.
          </li>
          <li>
            Workspace information &mdash; organization name, members, and
            billing details for paid web plans.
          </li>
          <li>
            Post content &mdash; the text, images, and video you compose, the
            per-channel overrides you set, and the times you schedule them for.
          </li>
          <li>Support requests and anything else you write to us.</li>
        </ul>
        <p>
          <strong>Information collected automatically.</strong>
        </p>
        <ul className="mt-[8px] list-inside list-disc space-y-[4px]">
          <li>
            Log and usage data &mdash; IP address, client type and version,
            requests made, timestamps, and errors, used to run and debug the
            Service.
          </li>
          <li>
            Device identifiers &mdash; an account identifier, a session
            identifier per signed-in device, and (only if you allow
            notifications) an Apple Push Notification service device token used
            to route notifications to your phone.
          </li>
          <li>
            Diagnostics &mdash; crash and error counts. These are collected on
            our own infrastructure and are not linked to your identity.{' '}
            {name} contains no third-party advertising or analytics SDKs, and
            does not use the iOS advertising identifier (IDFA).
          </li>
        </ul>
        <p>
          <strong>Information we do not collect.</strong> We do not collect
          precise or coarse location, your contacts, health or fitness data,
          financial data beyond what our payment processor handles for paid web
          plans, browsing history outside the Service, or any sensitive
          category of personal data.
        </p>
      </LegalSection>

      <LegalSection title="3. Connected Social Accounts">
        <p>
          When you connect a social account, you complete that network&rsquo;s
          own OAuth flow. We never see or store your password for it. We
          receive and store the profile identifier, display name and avatar
          shown in your channel list, and the access and refresh tokens needed
          to publish on your behalf.
        </p>
        <p>
          Tokens are stored encrypted and are used only to perform actions you
          asked for: publishing a post you scheduled, and reading back the
          engagement figures shown in the analytics screens. Disconnecting a
          channel in the app or on the web deletes the stored tokens for it.
        </p>
      </LegalSection>

      <LegalSection title="4. Photos, Camera, and Files on Your Device">
        <p>
          The iOS app asks for access to your photo library only when you
          attach media to a post. Selected media is uploaded to your workspace
          so it can be published at the scheduled time; nothing else in your
          library is read, indexed, or uploaded. Drafts you have not sent yet
          are kept on the device so a half-written post survives a lost signal,
          and they sync to your workspace when you are back online.
        </p>
      </LegalSection>

      <LegalSection title="5. Optional AI Features">
        <p>
          The AI copilot, image generation, and video drafting features are off
          until you turn them on, and each asks for consent before its first
          use. When you use one, the prompt and the post text you are working
          on are sent to the AI provider configured for your workspace solely
          to generate the requested output. Declining leaves the rest of the
          Service fully usable.
        </p>
      </LegalSection>

      <LegalSection title="6. Push Notifications">
        <p>
          Notifications are optional and off until you grant permission. They
          are used to tell you that a post published, that one failed, or that
          a channel needs reconnecting &mdash; each is a separate toggle in
          Settings. Revoking the permission in iOS Settings stops them
          immediately, and the stored device token is discarded.
        </p>
      </LegalSection>

      <LegalSection title="7. How We Use Your Information">
        <ul className="mt-[8px] list-inside list-disc space-y-[4px]">
          <li>Run, maintain, and improve the Service.</li>
          <li>
            Publish your posts to the channels you connected, at the times you
            chose.
          </li>
          <li>Process payments and send billing notices for paid web plans.</li>
          <li>Answer support requests.</li>
          <li>
            Send service notices. Product emails are optional and you can opt
            out of them.
          </li>
          <li>
            Detect abuse, enforce our Terms of Service, and keep accounts
            secure.
          </li>
          <li>Comply with the law.</li>
        </ul>
        <p>
          We do not use your data, or any data from your connected accounts, to
          track you across other companies&rsquo; apps or websites, and we do
          not sell it.
        </p>
      </LegalSection>

      <LegalSection title="8. Who We Share It With">
        <ul className="mt-[8px] list-inside list-disc space-y-[4px]">
          <li>
            <strong>The networks you connect</strong> &mdash; a post goes to
            exactly the channels you selected, when you told it to.
          </li>
          <li>
            <strong>Processors acting for us</strong> &mdash; hosting,
            transactional email, and payment processing, under
            data-processing terms and only to the extent needed.
          </li>
          <li>
            <strong>Your workspace members</strong> &mdash; posts, channels, and
            analytics inside an organization are visible to its other members
            per your permission settings.
          </li>
          <li>
            <strong>Legal</strong> &mdash; when required by law, court order, or
            a government authority, or to protect rights, property, or safety.
          </li>
          <li>
            <strong>Business transfer</strong> &mdash; in a merger, acquisition,
            or sale of assets, with notice to you.
          </li>
        </ul>
      </LegalSection>

      <LegalSection title="9. Retention and Deleting Your Account">
        <p>
          We keep your data for as long as your account is active. You can
          delete your account and all of its data from inside the iOS app
          (Settings &rarr; Delete account) or from the web app;
          no email to support is required. Deletion revokes your connected
          channel tokens immediately, and the data is permanently removed
          within 30 days except where the law requires us to keep a record
          longer. Posts already published to a social network stay on that
          network &mdash; delete them there.
        </p>
      </LegalSection>

      <LegalSection title="10. Your Rights">
        <p>Depending on where you live, you may have the right to:</p>
        <ul className="mt-[8px] list-inside list-disc space-y-[4px]">
          <li>Access the personal data we hold about you.</li>
          <li>Correct data that is wrong.</li>
          <li>Delete your data (&ldquo;right to erasure&rdquo;).</li>
          <li>Object to or restrict processing.</li>
          <li>Receive your data in a portable format.</li>
          <li>
            Withdraw consent &mdash; including disconnecting a channel or
            turning off the AI features &mdash; at any time.
          </li>
        </ul>
        <p>
          Email{' '}
          <a
            href={`mailto:${supportEmail}`}
            className="underline underline-offset-2 hover:text-white"
          >
            {supportEmail}
          </a>{' '}
          to exercise any of these. We respond within 30 days and may need to
          verify your identity first.
        </p>
      </LegalSection>

      <LegalSection title="11. Cookies and Analytics">
        <p>
          The web app uses cookies that are required for sign-in and session
          management. Product analytics are self-hosted, are not shared with
          advertising networks, and can be turned off in Settings. The iOS app
          uses no advertising cookies or trackers of any kind.
        </p>
      </LegalSection>

      <LegalSection title="12. Security">
        <p>
          Traffic is encrypted in transit with TLS, data is encrypted at rest,
          and connected-account tokens are encrypted separately with restricted
          access. You can review your signed-in devices and revoke any of them
          from inside the app. No system is perfectly secure, so we cannot
          promise absolute security, and we will notify affected users of a
          breach as required by law.
        </p>
      </LegalSection>

      <LegalSection title="13. Children">
        <p>
          The Service is a business tool and is not directed to children. An
          account requires you to be 18 or the age of majority where you live,
          as stated in our{' '}
          <a href="/terms" className="underline underline-offset-2 hover:text-white">
            Terms of Service
          </a>
          . We do not knowingly collect data from children; if you believe a
          child has given us data, contact us and we will delete it.
        </p>
      </LegalSection>

      <LegalSection title="14. International Transfers">
        <p>
          {companyName} is based in {jurisdiction}. If you use the Service from
          elsewhere, your data is transferred to and processed in{' '}
          {jurisdiction} or other countries where our processors operate, with
          the safeguards applicable law requires for such transfers.
        </p>
      </LegalSection>

      <LegalSection title="15. Changes">
        <p>
          We may update this policy. Material changes are posted here with a
          new effective date and, where appropriate, emailed to you or shown in
          the app. Continuing to use the Service after a change means you
          accept it.
        </p>
      </LegalSection>

      <LegalSection title="16. Contact">
        <p>
          Privacy questions, data requests, or a concern to report:{' '}
          <a
            href={`mailto:${supportEmail}`}
            className="underline underline-offset-2 hover:text-white"
          >
            {supportEmail}
          </a>
          {address ? <> or by post at {companyName}, {address}.</> : null}
        </p>
        <p>
          Our{' '}
          <a href="/terms" className="underline underline-offset-2 hover:text-white">
            Terms of Service
          </a>{' '}
          apply alongside this Privacy Policy.
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
