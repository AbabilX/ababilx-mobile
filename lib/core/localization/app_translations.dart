import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/profile/providers/profile_provider.dart';

final appLanguageProvider = Provider<String>((ref) {
  final isLoggedIn = ref.watch(isAuthenticatedProvider);
  if (!isLoggedIn) return 'en';

  final profileAsync = ref.watch(profileProvider);
  return profileAsync.maybeWhen(
    data: (user) => user.appLanguage.toLowerCase(),
    orElse: () => 'en',
  );
});

class AppTranslations {
  AppTranslations._();

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'login_subtitle':
          'Automated standup updates & Slack daily syncs for modern engineering teams.',
      'continue_google': 'Continue with Google',
      'messages': 'Messages',
      'wall': 'Wall',
      'profile': 'Profile',

      'app_language': 'Application Language',
      'sign_out': 'Sign Out',
      'github_connection': 'GitHub Connection',
      'slack_workspace': 'Slack Workspace',
      'provider': 'Provider',
      'confirm_signout': 'Are you sure you want to sign out?',
      'cancel': 'Cancel',
    },
    'bn': {
      'login_subtitle':
          'আধুনিক প্রকৌশলীদের জন্য স্বয়ংক্রিয় স্ট্যান্ডআপ আপডেট এবং স্ল্যাক দৈনিক সমলয়করণ।',
      'continue_google': 'গুগল অ্যাকাউন্ট দিয়ে এগিয়ে যান',
      'messages': 'বার্তা',
      'wall': 'ওয়াল',
      'profile': 'ব্যবহারকারী পরিচিতি',

      'app_language': 'অ্যাপ্লিকেশনের ভাষা',
      'sign_out': 'প্রস্থান করুন',
      'github_connection': 'গিটহাব সংযোগ',
      'slack_workspace': 'স্ল্যাক কার্যক্ষেত্র',
      'provider': 'প্রবেশ মাধ্যম',
      'confirm_signout': 'আপনি কি নিশ্চিত যে আপনি প্রস্থান করতে চান?',
      'cancel': 'বাতিল',
    }
  };

  static String translate(BuildContext context, WidgetRef ref, String key) {
    final lang = ref.watch(appLanguageProvider);
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
