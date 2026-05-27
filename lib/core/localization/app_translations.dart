import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/profile/providers/profile_provider.dart';

final appLanguageProvider = Provider<String>((ref) {
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
      'login_subtitle': 'Automated standup updates & Slack daily syncs for modern engineering teams.',
      'continue_google': 'Continue with Google',
      'rules': 'Rules',
      'profile': 'Profile',
      'active_rules': 'Active Rules',
      'paused_rules': 'Paused Rules',
      'rules_title': 'Standup Rules',
      'create_first_rule': 'Create first rule',
      'no_rules_desc': 'Create a rule to automatically send standup messages to Slack.',
      'rule_trigger_now': 'Trigger Now',
      'rule_history': 'History',
      'rule_edit': 'Edit',
      'rule_preview': 'Preview',
      'rule_active': 'Active',
      'rule_paused': 'Paused',
      'new_rule': 'New Rule',
      'edit_rule': 'Edit Rule',
      'rule_name': 'Rule Name',
      'slack_channel': 'Slack Destination Channel',
      'scheduling_mode': 'Scheduling Mode',
      'active_days': 'Select Active Days',
      'target_date': 'Target Delivery Date',
      'send_time': 'Send Time',
      'timezone': 'Scheduler Timezone',
      'notification': 'Pre-send Review Notification',
      'options': 'Standup Options',
      'ai_guidelines': 'AI Standup Guidelines',
      'example_output': 'Example Output Style',
      'save_config': 'Save Standup Config',
      'launch_standup': 'Launch Auto Standup',
      'review_standup': 'Review Standup',
      'msg_preview': 'Message Preview',
      'ai_workspace': 'AI Draft Workspace',
      'send_now': 'Send Standup Now',
      'save_auto_send': 'Save & Auto-Send Later',
      'ignore_send': 'Ignore — Send Auto-Draft',
      'close_workspace': 'Close Workspace',
      'msg_history': 'Message History',
      'no_messages': 'No messages sent yet',
      'no_messages_desc': 'Messages will appear here after the rule fires.',
      'sent': 'Sent',
      'app_language': 'Application Language',
      'sign_out': 'Sign Out',
      'github_connection': 'GitHub Connection',
      'slack_workspace': 'Slack Workspace',
      'provider': 'Provider',
      'confirm_signout': 'Are you sure you want to sign out?',
      'cancel': 'Cancel',
    },
    'bn': {
      'login_subtitle': 'আধুনিক ইঞ্জিনিয়ারদের জন্য স্বয়ংক্রিয় স্ট্যান্ডআপ আপডেট এবং স্ল্যাক ডেইলি সিঙ্ক।',
      'continue_google': 'গুগল দিয়ে এগিয়ে যান',
      'rules': 'রুলস',
      'profile': 'প্রোফাইল',
      'active_rules': 'সক্রিয় রুলস',
      'paused_rules': 'স্থগিত রুলস',
      'rules_title': 'স্ট্যান্ডআপ রুলস',
      'create_first_rule': 'প্রথম রুল তৈরি করুন',
      'no_rules_desc': 'স্বয়ংক্রিয়ভাবে স্ল্যাকে স্ট্যান্ডআপ বার্তা পাঠাতে একটি রুল তৈরি করুন।',
      'rule_trigger_now': 'এখনই ট্রিগার',
      'rule_history': 'ইতিহাস',
      'rule_edit': 'সম্পাদনা',
      'rule_preview': 'প্রিভিউ',
      'rule_active': 'সক্রিয়',
      'rule_paused': 'স্থগিত',
      'new_rule': 'নতুন রুল',
      'edit_rule': 'রুল সম্পাদন',
      'rule_name': 'রুলের নাম',
      'slack_channel': 'স্ল্যাক গন্তব্য চ্যানেল',
      'scheduling_mode': 'শিডিউলিং মোড',
      'active_days': 'সক্রিয় দিনগুলো নির্বাচন করুন',
      'target_date': 'বার্তা পাঠানোর তারিখ',
      'send_time': 'পাঠানোর সময়',
      'timezone': 'শিডিউলার টাইমজোন',
      'notification': 'পাঠানোর আগে পর্যালোচনা নোটিফিকেশন',
      'options': 'স্ট্যান্ডআপ অপশনস',
      'ai_guidelines': 'এআই স্ট্যান্ডআপ গাইডলাইনস',
      'example_output': 'আউটপুটের নমুনা স্টাইল',
      'save_config': 'কনফিগ সংরক্ষণ করুন',
      'launch_standup': 'অটো স্ট্যান্ডআপ শুরু করুন',
      'review_standup': 'স্ট্যান্ডআপ পর্যালোচনা',
      'msg_preview': 'বার্তার প্রাকদর্শন',
      'ai_workspace': 'এআই ড্রাফট ওয়ার্কস্পেস',
      'send_now': 'এখনই স্ট্যান্ডআপ পাঠান',
      'save_auto_send': 'সংরক্ষণ করুন এবং পরে অটো পাঠান',
      'ignore_send': 'উপেক্ষা করুন — অটো-ড্রাফট পাঠান',
      'close_workspace': 'ওয়ার্কস্পেস বন্ধ করুন',
      'msg_history': 'বার্তার ইতিহাস',
      'no_messages': 'কোনো বার্তা পাঠানো হয়নি',
      'no_messages_desc': 'রুলটি ফায়ার হওয়ার পর বার্তাগুলো এখানে প্রদর্শিত হবে।',
      'sent': 'পাঠানো হয়েছে',
      'app_language': 'অ্যাপ্লিকেশনের ভাষা',
      'sign_out': 'লগ আউট',
      'github_connection': 'গিটহাব সংযোগ',
      'slack_workspace': 'স্ল্যাক ওয়ার্কস্পেস',
      'provider': 'প্রোভাইডার',
      'confirm_signout': 'আপনি কি নিশ্চিত যে আপনি লগ আউট করতে চান?',
      'cancel': 'বাতিল',
    }
  };

  static String translate(BuildContext context, WidgetRef ref, String key) {
    final lang = ref.watch(appLanguageProvider);
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
