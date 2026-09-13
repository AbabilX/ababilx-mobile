import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/auth/providers/auth_provider.dart';
import 'package:ababilx/features/profile/data/profile_repository.dart';
import 'package:ababilx/features/profile/providers/profile_provider.dart';
import 'package:ababilx/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Profile extends ProfileNotifier {
  @override
  Future<AppUser> build() async => const AppUser(
    id: 'u1',
    name: 'Murad',
    email: 'm@x.com',
    provider: 'google',
    appLanguage: 'bn',
  );
}

void main() {
  test('en and bn translation maps share the same keys', () {
    final en = AppTranslations.keysOf('en');
    final bn = AppTranslations.keysOf('bn');
    expect(en.difference(bn), isEmpty, reason: 'missing in bn');
    expect(bn.difference(en), isEmpty, reason: 'extra in bn');
  });

  testWidgets('settings hub is Bangla when app language is bn', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAuthenticatedProvider.overrideWith((ref) => true),
          profileProvider.overrideWith(_Profile.new),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('সেটিংস'), findsOneWidget);
    expect(find.text('বিজ্ঞপ্তি'), findsOneWidget);
    expect(find.text('অ্যাপ্লিকেশনের ভাষা'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Notifications'), findsNothing);
    expect(find.text('যে মাধ্যমে সাইন ইন'), findsNothing);
    expect(find.text('গিটহাব সংযোগ'), findsNothing);
    expect(find.text('স্ল্যাক কার্যক্ষেত্র'), findsNothing);
    expect(find.text('Murad'), findsOneWidget);
    expect(find.text('প্ল্যান'), findsNothing);
  });
}
