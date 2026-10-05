const mailMock = jest.fn();
jest.mock('@cuantolabs/mail', () => ({
  __esModule: true,
  default: (...args: unknown[]) => mailMock(...args),
}));

import { PlunkProvider } from '@gitroom/nestjs-libraries/emails/plunk.provider';

describe('PlunkProvider', () => {
  beforeEach(() => mailMock.mockReset());

  it('sends through @cuantolabs/mail with the from name/address combined', async () => {
    mailMock.mockResolvedValue({ data: { id: 'abc' }, error: null });
    const provider = new PlunkProvider();

    const result = await provider.sendEmail(
      'to@example.com',
      'Subject',
      '<p>hi</p>',
      'Cuanto Socials',
      'noreply@socials.cuantolabs.com',
      'reply@example.com'
    );

    expect(mailMock).toHaveBeenCalledWith({
      from: 'Cuanto Socials <noreply@socials.cuantolabs.com>',
      to: 'to@example.com',
      subject: 'Subject',
      html: '<p>hi</p>',
      replyTo: 'reply@example.com',
    });
    expect(result).toEqual({ id: 'abc' });
  });

  it('omits replyTo when not given', async () => {
    mailMock.mockResolvedValue({ data: { id: 'abc' }, error: null });
    const provider = new PlunkProvider();

    await provider.sendEmail(
      'to@example.com',
      'Subject',
      '<p>hi</p>',
      'Cuanto Socials',
      'noreply@socials.cuantolabs.com'
    );

    expect(mailMock).toHaveBeenCalledWith(
      expect.not.objectContaining({ replyTo: expect.anything() })
    );
  });

  it('returns { sent: false } and logs on error, never throws', async () => {
    mailMock.mockResolvedValue({ data: null, error: { message: 'boom' } });
    const provider = new PlunkProvider();

    const result = await provider.sendEmail(
      'to@example.com',
      'Subject',
      '<p>hi</p>',
      'Cuanto Socials',
      'noreply@socials.cuantolabs.com'
    );

    expect(result).toEqual({ sent: false });
  });
});
