import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/onboarding/profile-setup/profile_setup_gate.dart';
import 'package:ababilx/features/onboarding/profile-setup/profile_setup_store.dart';
import 'package:ababilx/features/profile/data/profile_repository.dart';
import 'package:ababilx/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Profile extends ProfileNotifier {
  _Profile(this.user);
  final AppUser user;
  final saved = <String>[];

  @override
  Future<AppUser> build() async => user;

  @override
  Future<void> updateUsername(String username) async {
    saved.add(username);
    state = AsyncData(state.value!.copyWith(username: username));
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  AppUser user({required bool isNew}) => AppUser(
    id: 'u1',
    name: 'Murad',
    email: 'm@example.com',
    provider: 'google',
    isNewAccount: isNew,
  );

  Future<_Profile> show(WidgetTester tester, AppUser user) async {
    final profile = _Profile(user);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLanguageProvider.overrideWithValue('en'),
          profileProvider.overrideWith(() => profile),
        ],
        child: const MaterialApp(
          home: ProfileSetupGate(child: Text('chat list')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return profile;
  }

  test('due for a new account, or one that started and did not finish', () {
    expect(profileSetupDue(isNewAccount: true, stored: null), isTrue);
    expect(profileSetupDue(isNewAccount: false, stored: null), isFalse);
    expect(
      profileSetupDue(isNewAccount: false, stored: ProfileSetupStore.pending),
      isTrue,
    );
    expect(
      profileSetupDue(isNewAccount: true, stored: ProfileSetupStore.done),
      isFalse,
    );
  });

  testWidgets('an existing account goes straight to the app', (tester) async {
    await show(tester, user(isNew: false));
    expect(find.text('chat list'), findsOneWidget);
  });

  testWidgets('name, username, then a skippable phone number', (tester) async {
    final profile = await show(tester, user(isNew: true));
    expect(find.text('Your name'), findsOneWidget);
    expect(await ProfileSetupStore.read('u1'), ProfileSetupStore.pending);

    // The provider's name is kept as it is: nothing to save.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a username'), findsOneWidget);

    // A username is required: Next is dead until one is typed.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a username'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Murad.Dev');
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(profile.saved, ['murad.dev']);
    expect(find.text('Add your phone number'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('chat list'), findsOneWidget);
    expect(await ProfileSetupStore.read('u1'), ProfileSetupStore.done);
  });
}
