/**
 * /privacy — Privacy Policy.
 *
 * This is a TEMPLATE (ported from the Cuanto Labs saas-starter pattern). Review
 * every section with qualified legal counsel before treating it as final,
 * especially if you operate under GDPR, CCPA, or other privacy laws. The
 * NOT-LEGAL-ADVICE banner is intentional and must not be removed without that
 * review happening first.
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

const EFFECTIVE_DATE = 'July 22, 2026';

export const metadata: Metadata = {
  title: `Privacy Policy · ${BRAND.name}`,
  description: `Privacy Policy for ${BRAND.name} — how we collect, use, and protect your data.`,
  robots: { index: true, follow: false },
};

export default function PrivacyPage() {
  const { name, url, supportEmail } = BRAND;
  const { companyName, address, jurisdiction } = BRAND.legal;

  return (
    <div className="mx-auto max-w-[720px] px-[16px] py-[64px] text-white">
      {/* NOT-LEGAL-ADVICE banner — do not remove */}
      <div className="mb-[40px] rounded-[8px] border border-amber-700 bg-amber-950/40 px-[20px] py-[16px] text-amber-200 text-[13px]">
        <strong>Template notice.</strong> This Privacy Policy is a
        starting-point template and is <strong>not legal advice</strong>.
        Privacy law varies significantly by jurisdiction (GDPR, CCPA, PIPEDA,
        etc.). Have qualified legal counsel review and adapt this document
        before treating it as final.
      </div>

      <h1 className="mb-[8px] font-bold text-[36px] tracking-tight">
        Privacy Policy
      </h1>
      <p className="mb-[40px] text-white/60 text-[13px]">
        Effective date: {EFFECTIVE_DATE} &mdash; {companyName}
        {address ? `, ${address}` : ''}
      </p>

      <LegalSection title="1. Who We Are">
        <p>
          {companyName}{' '}
          (&ldquo;we,&rdquo; &ldquo;us,&rdquo; or &ldquo;our&rdquo;) operates{' '}
          {name} at{' '}
          <a href={url} className="underline underline-offset-2 hover:text-white">
            {url}
          </a>{' '}
          (the &ldquo;Service&rdquo;). This Privacy Policy explains how we
          collect, use, and share information when you use the Service.
        </p>
      </LegalSection>

      <LegalSection title="2. Information We Collect">
        <p>We collect information you provide directly:</p>
        <ul className="mt-[8px] list-inside list-disc space-y-[4px]">
          <li>Account information (name, email address, password hash).</li>
          <li>Organization details (workspace name, billing information).</li>
          <li>
            Post content, media, and scheduling data you create in the
            Service.
          </li>
          <li>Communications you send us (support requests, feedback).</li>
        </ul>
        <p>We collect information automatically when you use the Service:</p>
        <ul className="mt-[8px] list-inside list-disc space-y-[4px]">
          <li>Log data (IP address, browser type, pages visited, timestamps).</li>
          <li>Usage data (feature interactions, session duration).</li>
          <li>Device information (operating system, screen resolution).</li>
        </ul>
        <p>
          When you connect a third-party account (such as LinkedIn for
          posting, or Google for sign-in), we receive information from that
          provider as authorized by the permissions you grant during that
          connection — typically your profile identifier, email address, and
          the access token needed to publish posts or verify your identity.
          We do not receive your password for those services.
        </p>
      </LegalSection>

      <LegalSection title="3. How We Use Your Information">
        <p>We use your information to:</p>
        <ul className="mt-[8px] list-inside list-disc space-y-[4px]">
          <li>Provide, maintain, and improve the Service.</li>
          <li>
            Publish and manage posts to the third-party accounts you connect,
            on your instruction.
          </li>
          <li>Process transactions and send billing-related notices.</li>
          <li>Respond to support requests and communicate with you.</li>
          <li>Send product updates (you may opt out of non-essential ones).</li>
          <li>Monitor for abuse, enforce our Terms of Service, and ensure security.</li>
          <li>Comply with legal obligations.</li>
        </ul>
      </LegalSection>

      <LegalSection title="4. How We Share Your Information">
        <p>We do not sell your personal data. We may share information with:</p>
        <ul className="mt-[8px] list-inside list-disc space-y-[4px]">
          <li>
            <strong>The third-party platforms you connect</strong> — content
            you schedule is sent to LinkedIn (or other platforms you connect)
            as directed by you.
          </li>
          <li>
            <strong>Service providers</strong> — processors acting on our
            behalf (hosting, payments, email, analytics) under
            data-processing agreements.
          </li>
          <li>
            <strong>Organization members</strong> — information visible
            within your workspace is accessible to other members per your
            permission settings.
          </li>
          <li>
            <strong>Legal obligations</strong> — when required by law, court
            order, or government authority; or to protect rights, property,
            or safety.
          </li>
          <li>
            <strong>Business transfers</strong> — in connection with a
            merger, acquisition, or sale of assets, with notice to you.
          </li>
        </ul>
      </LegalSection>

      <LegalSection title="5. Data Retention">
        <p>
          We retain your data for as long as your account is active or as
          needed to provide the Service. After account deletion, we retain
          data for up to 30 days before permanent deletion, except where we
          are required to retain it longer by law. Disconnecting a
          third-party account revokes our stored access token for that
          account promptly.
        </p>
      </LegalSection>

      <LegalSection title="6. Your Rights">
        <p>Depending on your jurisdiction, you may have the right to:</p>
        <ul className="mt-[8px] list-inside list-disc space-y-[4px]">
          <li>Access the personal data we hold about you.</li>
          <li>Request correction of inaccurate data.</li>
          <li>Request deletion of your data (&ldquo;right to erasure&rdquo;).</li>
          <li>Object to or restrict processing of your data.</li>
          <li>Receive your data in a portable format.</li>
          <li>Withdraw consent where processing is based on consent, including revoking a connected account.</li>
        </ul>
        <p>
          To exercise these rights, email us at{' '}
          <a
            href={`mailto:${supportEmail}`}
            className="underline underline-offset-2 hover:text-white"
          >
            {supportEmail}
          </a>
          . We will respond within 30 days. We may need to verify your
          identity before fulfilling a request.
        </p>
      </LegalSection>

      <LegalSection title="7. Cookies">
        <p>
          We use essential cookies required for authentication and session
          management. We may use analytics cookies to understand usage;
          these can be opted out of via your browser settings.
        </p>
        <p>We do not use third-party advertising cookies.</p>
      </LegalSection>

      <LegalSection title="8. Data Security">
        <p>
          We implement industry-standard technical and organizational
          measures to protect your data, including encryption in transit
          (TLS) and at rest, and access controls, including for third-party
          access tokens. No system is perfectly secure; we cannot guarantee
          absolute security.
        </p>
        <p>We will notify affected users of a data breach as required by applicable law.</p>
      </LegalSection>

      <LegalSection title="9. Children's Privacy">
        <p>
          The Service is not directed to children under 13 (or the
          applicable age of digital consent in your jurisdiction). We do not
          knowingly collect personal data from children. If you believe a
          child has provided us with their data, contact us and we will
          delete it.
        </p>
      </LegalSection>

      <LegalSection title="10. International Data Transfers">
        <p>
          {companyName}{' '}
          is based in {jurisdiction}. If you access the Service from outside
          this jurisdiction, your data may be transferred to and processed
          in {jurisdiction}{' '}
          or other countries. We ensure appropriate safeguards are in place
          for such transfers as required by applicable law.
        </p>
      </LegalSection>

      <LegalSection title="11. Changes to This Policy">
        <p>
          We may update this Privacy Policy from time to time. We will
          notify you of material changes by posting the updated policy on
          the Service and, where appropriate, sending an email notification.
          Your continued use of the Service after changes are posted
          constitutes acceptance.
        </p>
      </LegalSection>

      <LegalSection title="12. Contact Us">
        <p>
          For privacy-related questions, data subject requests, or to report
          a concern, contact us at{' '}
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
