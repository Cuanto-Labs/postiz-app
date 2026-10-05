import { EmailInterface } from '@gitroom/nestjs-libraries/emails/email.interface';

export class PlunkProvider implements EmailInterface {
  name = 'plunk';
  validateEnvKeys = ['MAIL_API_KEY', 'MAIL_FROM'];
  async sendEmail(
    to: string,
    subject: string,
    html: string,
    emailFromName: string,
    emailFromAddress: string,
    replyTo?: string
  ) {
    // @cuantolabs/mail is ESM-only (no CJS export); this app compiles to
    // CommonJS, so a top-level `import` would throw ERR_REQUIRE_ESM at
    // require-time. A dynamic import stays a real ESM load under commonjs
    // module emit and defers it to call time instead.
    const { default: mail } = await import('@cuantolabs/mail');
    const { data, error } = await mail({
      from: `${emailFromName} <${emailFromAddress}>`,
      to,
      subject,
      html,
      ...(replyTo && { replyTo }),
    });

    if (error) {
      console.log(error);
      return { sent: false };
    }

    return data;
  }
}
