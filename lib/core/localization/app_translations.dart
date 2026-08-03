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
      'board': 'Board',
      'profile': 'Profile',
      'chat_attach': 'Attach',
      'chat_format': 'Format',
      'chat_emoji': 'Emoji',
      'chat_mention': 'Mention someone',
      'chat_share_contact': 'Share contact',
      'chat_expand': 'Expand composer',
      'chat_send': 'Send',
      'chat_hold_to_record': 'Hold to record',
      'chat_tap_to_record': 'Tap to record',
      'chat_release_to_send': 'Release to send',
      'chat_recording_starting': 'Starting…',
      'chat_voice_sending': 'Sending…',
      'chat_voice_pause': 'Pause',
      'chat_voice_resume': 'Resume',

      'crm_section_customer': 'Customer',
      'crm_section_overview': 'Overview',
      'crm_section_setup': 'Setup',
      'crm_contacts': 'Contacts',
      'crm_leads': 'Leads',
      'crm_followups': 'Follow-ups',
      'crm_organizations': 'Organizations',
      'crm_payments': 'Payments',
      'crm_add_payment': 'Add payment',
      'crm_remaining': 'Remaining',
      'crm_paid': 'Paid',
      'crm_payment_complete': 'Payment complete',
      'crm_payment_locked': 'Payments are locked after a lead is closed.',
      'crm_refund': 'Refund',
      'crm_record_payment': 'Record payment',
      'crm_payment_amount': 'Amount',
      'crm_payment_method': 'Method',
      'crm_payment_reference': 'Reference',
      'crm_save_payment': 'Save payment',
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
      'crm_my_short': 'My',
      'crm_all_short': 'All',
      'crm_add_short': 'Add',
      'crm_search_contacts': 'Search name, email, company…',
      'crm_search_empty': 'No contacts found',
      'crm_search_leads': 'Search title, contact, owner…',
      'crm_search_leads_empty': 'No leads found',
      'crm_leads_empty_mine': 'No leads assigned to you yet.',
      'crm_leads_empty_all': 'No leads yet.',
      'crm_search_followups': 'Search contact, company, assignee…',
      'crm_search_followups_empty': 'No follow-ups found',
      'crm_followups_empty': 'No follow-ups match this view.',
      'crm_delete_confirm': 'This cannot be undone.',

      'app_language': 'Application Language',
      'sign_out': 'Sign Out',
      'github_connection': 'GitHub Connection',
      'slack_workspace': 'Slack Workspace',
      'provider': 'Provider',
      'confirm_signout': 'Are you sure you want to sign out?',
      'cancel': 'Cancel',
      'notif_enable_title': 'Enable notifications',
      'notif_enable_body':
          'Tap to allow push alerts for standups and team updates.',
      'notif_enabled': 'Notifications enabled',
      'notif_still_denied': 'Permission still denied — check system settings',
      'battery_opt_title': 'Battery optimization',
      'battery_opt_need_body':
          'Turn off optimization so push notifications keep working in the background.',
      'battery_opt_ok_body':
          'Unrestricted — AbabilX can deliver notifications reliably.',
      'battery_opt_prompt_body':
          'Android may pause AbabilX to save battery, which stops notifications after a while. Allow “Ignore battery optimizations” so alerts keep working like WhatsApp.',
      'battery_opt_allow': 'Allow',
      'battery_opt_later': 'Later',
      'battery_opt_enabled': 'Battery optimization disabled for AbabilX',
      'battery_opt_still_denied':
          'Still restricted — enable Unrestricted in battery settings',

      'policy_title': 'Privacy & Policy',
      'policy_subtitle': 'A quick summary before you continue.',
      'policy_bullet_1':
          'We store your profile, connected accounts, and the content you create (messages, posts, tasks).',
      'policy_bullet_2':
          'No ads, no trackers, no selling your data — ever.',
      'policy_bullet_3':
          'AI features process your content only to generate the summary you asked for.',
      'policy_bullet_4':
          'Disconnect integrations or delete your account anytime from Settings.',
      'policy_read_full': 'Read the full policy',
      'policy_accept': 'I Agree',
      'policy_decline_signout': 'Decline & Sign Out',
      'policy_error': 'Could not save. Try again.',
    },
    'bn': {
      'login_subtitle':
          'আধুনিক প্রকৌশলীদের জন্য স্বয়ংক্রিয় স্ট্যান্ডআপ আপডেট এবং স্ল্যাক দৈনিক সমলয়করণ।',
      'continue_google': 'গুগল অ্যাকাউন্ট দিয়ে এগিয়ে যান',
      'messages': 'বার্তা',
      'wall': 'ওয়াল',
      'crm': 'CRM',
      'board': 'বোর্ড',
      'profile': 'ব্যবহারকারী পরিচিতি',
      'chat_attach': 'সংযুক্ত করুন',
      'chat_format': 'ফরম্যাট',
      'chat_emoji': 'ইমোজি',
      'chat_mention': 'কাউকে মেনশন করুন',
      'chat_share_contact': 'কন্টাক্ট শেয়ার করুন',
      'chat_expand': 'কম্পোজার বড় করুন',
      'chat_send': 'পাঠান',
      'chat_hold_to_record': 'রেকর্ড করতে ধরে রাখুন',
      'chat_tap_to_record': 'রেকর্ড করতে ট্যাপ করুন',
      'chat_release_to_send': 'পাঠাতে ছেড়ে দিন',
      'chat_recording_starting': 'শুরু হচ্ছে…',
      'chat_voice_sending': 'পাঠানো হচ্ছে…',
      'chat_voice_pause': 'পজ করুন',
      'chat_voice_resume': 'আবার চালু করুন',

      'crm_section_customer': 'কাস্টমার',
      'crm_section_overview': 'ওভারভিউ',
      'crm_section_setup': 'সেটআপ',
      'crm_contacts': 'কন্টাক্টস',
      'crm_leads': 'লিডস',
      'crm_followups': 'ফলো-আপ',
      'crm_organizations': 'প্রতিষ্ঠান',
      'crm_payments': 'পেমেন্ট',
      'crm_add_payment': 'পেমেন্ট যোগ করুন',
      'crm_remaining': 'বাকি',
      'crm_paid': 'পরিশোধিত',
      'crm_payment_complete': 'পেমেন্ট সম্পূর্ণ',
      'crm_payment_locked': 'লিড বন্ধ হওয়ার পরে পেমেন্ট পরিবর্তন করা যাবে না।',
      'crm_refund': 'ফেরত',
      'crm_record_payment': 'পেমেন্ট রেকর্ড করুন',
      'crm_payment_amount': 'পরিমাণ',
      'crm_payment_method': 'মাধ্যম',
      'crm_payment_reference': 'রেফারেন্স',
      'crm_save_payment': 'পেমেন্ট সংরক্ষণ করুন',
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
      'crm_my_short': 'আমার',
      'crm_all_short': 'সব',
      'crm_add_short': 'যোগ',
      'crm_search_contacts': 'নাম, ইমেইল, কোম্পানি খুঁজুন…',
      'crm_search_empty': 'কোনো কন্টাক্ট পাওয়া যায়নি',
      'crm_search_leads': 'টাইটেল, কন্টাক্ট, ওনার খুঁজুন…',
      'crm_search_leads_empty': 'কোনো লিড পাওয়া যায়নি',
      'crm_leads_empty_mine': 'তোমার কোনো লিড এখনো নেই।',
      'crm_leads_empty_all': 'এখনো কোনো লিড নেই।',
      'crm_search_followups': 'কন্টাক্ট, কোম্পানি, অ্যাসাইনি খুঁজুন…',
      'crm_search_followups_empty': 'কোনো ফলো-আপ পাওয়া যায়নি',
      'crm_followups_empty': 'এই ভিউতে কোনো ফলো-আপ নেই।',
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
      'notif_still_denied': 'অনুমতি এখনো বন্ধ — সিস্টেম সেটিংস চেক করুন',
      'battery_opt_title': 'ব্যাটারি অপটিমাইজেশন',
      'battery_opt_need_body':
          'ব্যাকগ্রাউন্ডে নোটিফিকেশন চালু রাখতে অপটিমাইজেশন বন্ধ করুন।',
      'battery_opt_ok_body':
          'আনরেস্ট্রিক্টেড — AbabilX নির্ভরযোগ্যভাবে নোটিফিকেশন দিতে পারবে।',
      'battery_opt_prompt_body':
          'অ্যান্ড্রয়েড ব্যাটারি বাঁচাতে AbabilX পজ করতে পারে, এতে কিছুক্ষণ পর নোটিফিকেশন বন্ধ হয়ে যায়। WhatsApp-এর মতো অ্যালার্ট চালু রাখতে “Ignore battery optimizations” অনুমতি দিন।',
      'battery_opt_allow': 'অনুমতি দিন',
      'battery_opt_later': 'পরে',
      'battery_opt_enabled': 'AbabilX-এর জন্য ব্যাটারি অপটিমাইজেশন বন্ধ',
      'battery_opt_still_denied':
          'এখনো সীমিত — ব্যাটারি সেটিংসে Unrestricted চালু করুন',

      'policy_title': 'গোপনীয়তা ও নীতিমালা',
      'policy_subtitle': 'চালিয়ে যাওয়ার আগে একটি সংক্ষিপ্ত সারাংশ।',
      'policy_bullet_1':
          'আমরা আপনার প্রোফাইল, সংযুক্ত অ্যাকাউন্ট এবং আপনার তৈরি কন্টেন্ট (বার্তা, পোস্ট, টাস্ক) সংরক্ষণ করি।',
      'policy_bullet_2':
          'কোনো বিজ্ঞাপন নেই, ট্র্যাকার নেই, আপনার ডেটা কখনো বিক্রি করা হয় না।',
      'policy_bullet_3':
          'AI ফিচার শুধু আপনার অনুরোধ করা সারাংশ তৈরি করতে আপনার কন্টেন্ট প্রক্রিয়া করে।',
      'policy_bullet_4':
          'সেটিংস থেকে যেকোনো সময় ইন্টিগ্রেশন সংযোগ বিচ্ছিন্ন বা অ্যাকাউন্ট মুছে ফেলতে পারবেন।',
      'policy_read_full': 'সম্পূর্ণ নীতিমালা পড়ুন',
      'policy_accept': 'আমি সম্মত',
      'policy_decline_signout': 'প্রত্যাখ্যান ও প্রস্থান',
      'policy_error': 'সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।',
    },
  };

  static String translate(BuildContext context, WidgetRef ref, String key) {
    final lang = ref.watch(appLanguageProvider);
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
