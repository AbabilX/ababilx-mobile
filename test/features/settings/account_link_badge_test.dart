import 'package:ababilx/features/profile/data/profile_repository.dart';
import 'package:ababilx/features/settings/settings-hub/account_link_badge.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user({String provider = 'google', String githubUsername = ''}) =>
    AppUser(
      id: 'u1',
      name: 'Murad',
      email: 'm@x.com',
      provider: provider,
      githubUsername: githubUsername,
    );

void main() {
  test('accountLinks shows only the sign-in provider', () {
    expect(accountLinks(_user(githubUsername: 'murad')), [AccountLink.google]);
    expect(accountLinks(_user(provider: 'github', githubUsername: 'murad')), [
      AccountLink.github,
    ]);
    expect(accountLinks(_user(provider: 'qr')), [AccountLink.qr]);
  });

  test('no mark for an unknown provider', () {
    expect(accountLinks(_user(provider: '')), isEmpty);
  });
}
