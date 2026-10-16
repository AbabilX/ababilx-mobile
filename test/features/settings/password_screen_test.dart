import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/auth/email/email_auth_repository.dart';
import 'package:ababilx/features/auth/email/email_sign_in_screen.dart';
import 'package:ababilx/features/settings/password/password_repository.dart';
import 'package:ababilx/features/settings/password/password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements PasswordRepository {
  _FakeRepo(this.current);

  PasswordStatus current;
  int codesSent = 0;
  final saved = <String>[];
  Object? saveError;

  @override
  Future<PasswordStatus> status() async => current;

  @override
  Future<EmailCodeSent> sendCode() async {
    codesSent++;
    return const EmailCodeSent(
      maskedEmail: 'm***@gmail.com',
      resendIn: Duration(seconds: 60),
    );
  }

  @override
  Future<void> setPassword({
    required String code,
    required String password,
  }) async {
    if (saveError != null) throw saveError!;
    saved.add('$code:$password');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PasswordStatus _status({bool has = false, bool canSet = true}) =>
    PasswordStatus(hasPassword: has, email: 'me@gmail.com', canSet: canSet);

Future<void> _show(WidgetTester tester, _FakeRepo repo, Widget home) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLanguageProvider.overrideWithValue('en'),
          passwordRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(home: home),
      ),
    );

void main() {
  testWidgets('email sign-in offers no account creation', (tester) async {
    await _show(tester, _FakeRepo(_status()), const EmailSignInScreen());
    expect(find.text('Create account'), findsNothing);
    expect(find.text('New to AbabilX?'), findsNothing);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('a Google account sets its first password with a code', (
    tester,
  ) async {
    final repo = _FakeRepo(_status());
    await _show(tester, repo, const PasswordScreen());
    await tester.pumpAndSettle();
    expect(find.text('No password yet'), findsOneWidget);
    await tester.tap(find.text('Set password'));
    await tester.pump();
    await tester.pump();
    expect(repo.codesSent, 1);
    expect(find.textContaining('m***@gmail.com'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), 'correct horse');
    await tester.enterText(fields.at(2), 'correct hors');
    await tester.tap(find.text('Save password'));
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(repo.saved, isEmpty);

    await tester.enterText(fields.at(2), 'correct horse');
    await tester.tap(find.text('Save password'));
    await tester.pump();
    expect(repo.saved, ['123456:correct horse']);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a wrong code reads in the app language', (tester) async {
    final repo = _FakeRepo(_status(has: true))
      ..saveError = const EmailAuthException('invalid_code', 'server text');
    await _show(tester, repo, const PasswordScreen());
    await tester.pumpAndSettle();
    expect(find.text('Password is set'), findsOneWidget);
    await tester.tap(find.text('Change password'));
    await tester.pump();
    await tester.pump();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '000000');
    await tester.enterText(fields.at(1), 'another pass');
    await tester.enterText(fields.at(2), 'another pass');
    await tester.tap(find.text('Save password'));
    await tester.pump();
    expect(
      find.text('That code is wrong or expired. Request a new one.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('an account with no usable email cannot set one', (
    tester,
  ) async {
    final repo = _FakeRepo(_status(canSet: false));
    await _show(tester, repo, const PasswordScreen());
    await tester.pumpAndSettle();
    expect(find.text('Set password'), findsNothing);
    expect(find.textContaining('cannot be added'), findsOneWidget);
  });
}
