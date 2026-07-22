/**
 * /terms — Terms of Service.
 *
 * This is a TEMPLATE (ported from the Cuanto Labs saas-starter pattern). Review
 * every section with qualified legal counsel before treating it as final. The
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
  title: `Terms of Service · ${BRAND.name}`,
  description: `Terms of Service for ${BRAND.name} — ${BRAND.legal.companyName}.`,
  robots: { index: true, follow: false },
};

export default function TermsPage() {
  const { name, url, supportEmail } = BRAND;
  const { companyName, address, jurisdiction } = BRAND.legal;

  return (
    <div className="mx-auto max-w-[720px] px-[16px] py-[64px] text-white">
      {/* NOT-LEGAL-ADVICE banner — do not remove */}
      <div className="mb-[40px] rounded-[8px] border border-amber-700 bg-amber-950/40 px-[20px] py-[16px] text-amber-200 text-[13px]">
        <strong>Template notice.</strong> These Terms of Service are a
        starting-point template and are <strong>not legal advice</strong>.
        They may not be appropriate for every jurisdiction, business model,
        or user base. Review and customize every section with qualified
        legal counsel before treating this as final.
      </div>

      <h1 className="mb-[8px] font-bold text-[36px] tracking-tight">
        Terms of Service
      </h1>
      <p className="mb-[40px] text-white/60 text-[13px]">
        Effective date: {EFFECTIVE_DATE} &mdash; {companyName}
        {address ? `, ${address}` : ''}
      </p>

      <LegalSection title="1. Acceptance of Terms">
        <p>
          By accessing or using {name} (the &ldquo;Service&rdquo;) operated
          by {companyName} (&ldquo;we,&rdquo; &ldquo;us,&rdquo; or
          &ldquo;our&rdquo;), you agree to be bound by these Terms of
          Service (&ldquo;Terms&rdquo;). If you do not agree, do not use the
          Service.
        </p>
        <p>
          We may update these Terms at any time. Continued use after changes
          constitutes acceptance. We will provide reasonable notice of
          material changes via email or an in-app banner.
        </p>
      </LegalSection>

      <LegalSection title="2. Description of Service">
        <p>
          {name} is a social media scheduling and publishing platform
          accessible at{' '}
          <a href={url} className="underline underline-offset-2 hover:text-white">
            {url}
          </a>
          . It lets you connect social media accounts (such as LinkedIn) and
          third-party sign-in providers (such as Google), and schedule,
          publish, and manage posts across those connected accounts. Features
          and pricing are described on the website and may change with
          notice.
        </p>
      </LegalSection>

      <LegalSection title="3. Accounts and Eligibility">
        <p>
          You must be at least 18 years old (or the age of majority in your
          jurisdiction) to create an account. You are responsible for
          maintaining the confidentiality of your credentials and for all
          activity under your account.
        </p>
        <p>
          Organizations may designate multiple members. The account owner is
          responsible for all members&rsquo; activity and compliance with
          these Terms.
        </p>
      </LegalSection>

      <LegalSection title="4. Connected Accounts and Third-Party Platforms">
        <p>
          The Service integrates with third-party platforms (currently
          LinkedIn for posting, and Google for sign-in) via OAuth. When you
          connect an account, you authorize us to access and act on that
          account on your behalf within the scope of the permissions you
          grant, solely to provide the Service&rsquo;s scheduling and
          publishing features. Your use of any connected platform remains
          subject to that platform&rsquo;s own terms of service.
        </p>
      </LegalSection>

      <LegalSection title="5. Subscriptions and Payment">
        <p>
          Paid plans, where offered, are billed in advance on a monthly or
          annual basis. All fees are non-refundable except as required by
          applicable law or as described in our refund policy. We use a
          third-party payment processor; your payment information is subject
          to their terms.
        </p>
        <p>
          We may change pricing with 30 days&rsquo; notice. If you do not
          accept the new pricing, you may cancel before the change takes
          effect.
        </p>
      </LegalSection>

      <LegalSection title="6. Acceptable Use">
        <p>You agree not to:</p>
        <ul className="mt-[8px] list-inside list-disc space-y-[4px]">
          <li>Violate any applicable law or regulation.</li>
          <li>Upload or transmit malware, spam, or any harmful content.</li>
          <li>Attempt to gain unauthorized access to any system or data.</li>
          <li>Reverse-engineer, decompile, or disassemble the Service.</li>
          <li>Resell or sublicense the Service without written permission.</li>
          <li>
            Use the Service to infringe intellectual property rights of
            others, or to violate the terms of any connected third-party
            platform.
          </li>
        </ul>
        <p>
          We reserve the right to suspend or terminate accounts that violate
          these rules, with or without notice.
        </p>
      </LegalSection>

      <LegalSection title="7. Intellectual Property">
        <p>
          The Service and its content (excluding your data) are owned by{' '}
          {companyName} and protected by copyright, trademark, and other
          laws. You are granted a limited, non-exclusive, non-transferable
          license to use the Service for its intended purpose.
        </p>
        <p>
          You retain ownership of all data and content you submit to the
          Service (&ldquo;Customer Data&rdquo;), including post content and
          media. You grant us a limited license to process Customer Data
          solely to provide and improve the Service, including publishing it
          to the third-party accounts you connect.
        </p>
      </LegalSection>

      <LegalSection title="8. Privacy">
        <p>
          Our{' '}
          <a href="/privacy" className="underline underline-offset-2 hover:text-white">
            Privacy Policy
          </a>{' '}
          describes how we collect, use, and share information. By using the
          Service you agree to our Privacy Policy.
        </p>
      </LegalSection>

      <LegalSection title="9. Disclaimers">
        <p>
          THE SERVICE IS PROVIDED &ldquo;AS IS&rdquo; AND &ldquo;AS
          AVAILABLE&rdquo; WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR
          IMPLIED, INCLUDING WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
          PARTICULAR PURPOSE, OR NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE
          SERVICE WILL BE UNINTERRUPTED OR ERROR-FREE, OR THAT CONNECTED
          THIRD-PARTY PLATFORMS WILL REMAIN AVAILABLE OR COMPATIBLE.
        </p>
      </LegalSection>

      <LegalSection title="10. Limitation of Liability">
        <p>
          TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW,{' '}
          {companyName.toUpperCase()} SHALL NOT BE LIABLE FOR ANY INDIRECT,
          INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR LOSS OF
          PROFITS, REVENUE, DATA, OR GOODWILL, EVEN IF ADVISED OF THE
          POSSIBILITY OF SUCH DAMAGES.
        </p>
        <p>
          OUR TOTAL AGGREGATE LIABILITY TO YOU FOR CLAIMS ARISING UNDER
          THESE TERMS SHALL NOT EXCEED THE GREATER OF (A) THE AMOUNTS PAID
          BY YOU IN THE 12 MONTHS PRECEDING THE CLAIM OR (B) USD 100.
        </p>
      </LegalSection>

      <LegalSection title="11. Indemnification">
        <p>
          You agree to indemnify and hold {companyName}, its affiliates,
          officers, directors, employees, and agents harmless from any
          claim, demand, loss, or damages (including reasonable
          attorneys&rsquo; fees) arising from your use of the Service or
          violation of these Terms.
        </p>
      </LegalSection>

      <LegalSection title="12. Termination">
        <p>
          Either party may terminate the agreement at any time. Upon
          termination, your right to access the Service ceases immediately,
          and your connected third-party accounts will be disconnected. We
          will retain Customer Data for 30 days after termination, after
          which it may be deleted. You may export your data before
          termination.
        </p>
      </LegalSection>

      <LegalSection title="13. Governing Law and Disputes">
        <p>
          These Terms are governed by the laws of {jurisdiction}, without
          regard to conflict-of-law principles. Any dispute shall be
          resolved by binding arbitration in {jurisdiction}, except that
          either party may seek injunctive relief in a court of competent
          jurisdiction.
        </p>
      </LegalSection>

      <LegalSection title="14. Miscellaneous">
        <p>
          These Terms constitute the entire agreement between you and{' '}
          {companyName} regarding the Service. If any provision is held
          unenforceable, the remaining provisions remain in effect. Our
          failure to enforce any right is not a waiver of that right. You
          may not assign these Terms without our written consent.
        </p>
      </LegalSection>

      <LegalSection title="15. Contact">
        <p>
          Questions about these Terms? Contact us at{' '}
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
