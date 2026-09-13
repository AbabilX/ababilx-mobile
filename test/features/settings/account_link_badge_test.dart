import 'package:ababilx/features/profile/data/profile_repository.dart';
import 'package:ababilx/features/settings/settings-hub/account_link_badge.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user({
  String provider = 'google',
  String githubUsername = '',
  bool githubConnected = false,
  bool slackConnected = false,
}) => AppUser(
  id: 'u1',
  name: 'Murad',
  email: 'm@x.com',
  provider: provider,
  githubUsername: githubUsername,
  githubConnected: githubConnected,
  slackConnected: slackConnected,
);

void main() {
  test('accountLinks shows GitHub and Slack when those are connected', () {
    expect(
      accountLinks(
        _user(
          provider: 'google',
          githubUsername: 'murad',
          slackConnected: true,
        ),
      ),
      [AccountLink.google, AccountLink.github, AccountLink.slack],
    );
  });

  test('accountLinks does not duplicate GitHub when it is the provider', () {
    expect(accountLinks(_user(provider: 'github', githubUsername: 'murad')), [
      AccountLink.github,
    ]);
  });

  test('github_connected is enough even without a username', () {
    expect(accountLinks(_user(githubConnected: true)), [
      AccountLink.google,
      AccountLink.github,
    ]);
  });

  test('no extra marks when nothing is linked', () {
    expect(accountLinks(_user()), [AccountLink.google]);
    expect(accountLinks(_user(provider: '')), isEmpty);
  });
}
