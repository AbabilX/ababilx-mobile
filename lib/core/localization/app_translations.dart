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
      'crm': 'CRM',
      'profile': 'Profile',

      'crm_section_customer': 'Customer',
      'crm_section_overview': 'Overview',
      'crm_section_setup': 'Setup',
      'crm_contacts': 'Contacts',
      'crm_leads': 'Leads',
      'crm_followups': 'Follow-ups',
      'crm_dashboard': 'Dashboard',
      'crm_calendar': 'Calendar',
      'crm_timeline': 'Timeline',
      'crm_reports': 'Reports',
      'crm_settings': 'Settings',
      'crm_coming_soon': 'Coming soon',
      'crm_no_access': 'CRM locked',
      'crm_no_access_body':
          'Team premium and CRM permission are required. Ask a leader to grant access.',
      'crm_my_contacts': 'My contacts',
      'crm_all_contacts': 'All contacts',
      'crm_search_contacts': 'Search name, email, company…',
      'crm_delete_confirm': 'This cannot be undone.',

      'app_language': 'Application Language',
      'sign_out': 'Sign Out',
      'github_connection': 'GitHub Connection',
      'slack_workspace': 'Slack Workspace',
      'provider': 'Provider',
      'confirm_signout': 'Are you sure you want to sign out?',
      'cancel': 'Cancel',
      'notif_enable_title': 'Enable notifications',
      'notif_enable_body': 'Tap to allow push alerts for standups and team updates.',
      'notif_enabled': 'Notifications enabled',
      'notif_still_denied': 'Permission still denied — check system settings',
    },
    'bn': {
      'login_subtitle':
          'আধুনিক প্রকৌশলীদের জন্য স্বয়ংক্রিয় স্ট্যান্ডআপ আপডেট এবং স্ল্যাক দৈনিক সমলয়করণ।',
      'continue_google': 'গুগল অ্যাকাউন্ট দিয়ে এগিয়ে যান',
      'messages': 'বার্তা',
      'wall': 'ওয়াল',
      'crm': 'CRM',
      'profile': 'ব্যবহারকারী পরিচিতি',

      'crm_section_customer': 'কাস্টমার',
      'crm_section_overview': 'ওভারভিউ',
      'crm_section_setup': 'সেটআপ',
      'crm_contacts': 'কন্টাক্টস',
      'crm_leads': 'লিডস',
      'crm_followups': 'ফলো-আপ',
      'crm_dashboard': 'ড্যাশবোর্ড',
      'crm_calendar': 'ক্যালেন্ডার',
      'crm_timeline': 'টাইমলাইন',
      'crm_reports': 'রিপোর্টস',
      'crm_settings': 'সেটিংস',
      'crm_coming_soon': 'শীঘ্রই আসছে',
      'crm_no_access': 'CRM লক করা',
      'crm_no_access_body':
          'টিম প্রিমিয়াম ও CRM পারমিশন লাগবে। লিডারকে অ্যাক্সেস দিতে বলো।',
      'crm_my_contacts': 'আমার কন্টাক্টস',
      'crm_all_contacts': 'সব কন্টাক্টস',
      'crm_search_contacts': 'নাম, ইমেইল, কোম্পানি খুঁজুন…',
      'crm_delete_confirm': 'এটি আর ফেরানো যাবে না।',

      'app_language': 'অ্যাপ্লিকেশনের ভাষা',
      'sign_out': 'প্রস্থান করুন',
      'github_connection': 'গিটহাব সংযোগ',
      'slack_workspace': 'স্ল্যাক কার্যক্ষেত্র',
      'provider': 'প্রবেশ মাধ্যম',
      'confirm_signout': 'আপনি কি নিশ্চিত যে আপনি প্রস্থান করতে চান?',
      'cancel': 'বাতিল',
      'notif_enable_title': 'নোটিফিকেশন চালু করুন',
      'notif_enable_body':
          'স্ট্যান্ডআপ ও টিম আপডেটের জন্য পুশ অ্যালার্ট অনুমতি দিন।',
      'notif_enabled': 'নোটিফিকেশন চালু হয়েছে',
      'notif_still_denied':
          'অনুমতি এখনো বন্ধ — সিস্টেম সেটিংস চেক করুন',
    }
  };

  static String translate(BuildContext context, WidgetRef ref, String key) {
    final lang = ref.watch(appLanguageProvider);
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
