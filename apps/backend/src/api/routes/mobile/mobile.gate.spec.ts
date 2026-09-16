import { AuthService as AuthChecker } from '@gitroom/helpers/auth/auth.service';

describe('mobile gate smoke', () => {
  it('hashPassword/comparePassword roundtrip via alias import', () => {
    const hash = AuthChecker.hashPassword('mobile-gate-password');
    expect(AuthChecker.comparePassword('mobile-gate-password', hash)).toBe(true);
    expect(AuthChecker.comparePassword('wrong-password', hash)).toBe(false);
  });
});
