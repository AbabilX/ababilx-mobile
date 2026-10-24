import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';

/// Every Transfer chats string, English and Bangla. Kept beside the feature
/// rather than in `app_translations.dart`, which is past any useful size.
String transferText(WidgetRef ref, String key) {
  final table = ref.read(appLanguageProvider) == 'bn' ? _bn : _en;
  return table[key] ?? _en[key] ?? key;
}

const _en = {
  'card_title': 'Transfer chats from another phone',
  'card_body': 'Your old phone sends your chats over Wi-Fi.',
  'receive_title': 'Transfer chats',
  'receive_steps':
      'On your old phone: Settings → Account → Transfer chats → Scan code. Then scan this code.',
  'receive_same_wifi': 'Use the same Wi-Fi. Keep both phones open.',
  'receive_no_wifi': 'Connect this phone to Wi-Fi first.',
  'receive_retry': 'Try again',
  'receive_error': 'Could not start. Check your connection and try again.',
  'receiving': 'Receiving chats…',
  'importing': 'Saving chats…',
  'done_title': 'Chats transferred',
  'done_body': '{messages} messages and {files} files are on this phone.',
  'continue': 'Continue',
  'cancel': 'Cancel',
  'encrypted_note': 'Encrypted. Never sent through AbabilX servers.',
  'send_title': 'Sending chats',
  'send_connecting': 'Connecting to your new phone…',
  'send_sending': 'Sending {count} messages…',
  'send_waiting': 'Your new device is saving {count} messages…',
  'send_keep_open': 'Keep both open and on the same Wi-Fi.',
  'send_done': 'Your chats are on the new device.',
  'wipe_title': 'Delete chats from this phone?',
  'wipe_body': 'Messages and files leave this phone. You stay signed in.',
  'wipe_keep': 'Keep them',
  'wipe_delete': 'Delete',
  'wiped': 'Chats deleted from this phone.',
  'close': 'Close',
  'settings_title': 'Transfer chats',
  'screen_body':
      'Move your chats, files and message key to a new phone or computer.',
  'step_new':
      'On the new phone or computer, open AbabilX and choose Transfer chats. It shows a code.',
  'step_wifi': 'Connect both to the same Wi-Fi.',
  'step_scan': 'Tap Scan code below and scan that code.',
  'scan_button': 'Scan code',
  'scan_title': 'Scan the code',
  'scan_hint': 'The code is on your new phone or computer.',
  'scan_computer_title': "Scan the computer's code",
  'scan_computer_hint':
      'On the computer: Settings → Security → Transfer chats → Send chats.',
  'error_not_transfer':
      'That is not a Transfer chats code. Scan the code on your new phone or computer.',
  'settings_sub': 'Move your chats to a new phone or computer',
  'error_other_account':
      'That code belongs to a device signed in to another account.',
  'from_computer': 'Chats on a computer? Scan its code',
  'error_pull_here':
      "That code sends a computer's chats to a new phone. Scan it from the new phone's restore screen.",
  'error_not_computer':
      "That is not a computer's Transfer chats code. On the computer open Settings → Security → Send chats to a phone.",
  'error_locked': 'This phone has no message key to send.',
  'error_unreachable':
      'Could not reach the new phone. Put both on the same Wi-Fi and scan again.',
  'error_refused': 'The new phone stopped the transfer. Scan a new code.',
  'error_lost': 'The connection was lost. Scan a new code to start again.',
  'error_wrong_account': 'Those chats belong to another account.',
  'error_incomplete': 'The transfer stopped before the end. Try again.',
  'error_no_space': 'This phone ran out of space.',
  'error_failed': 'The transfer failed. Try again.',
};

const _bn = {
  'card_title': 'অন্য ফোন থেকে চ্যাট আনুন',
  'card_body': 'আপনার পুরোনো ফোন Wi-Fi দিয়ে চ্যাট পাঠাবে।',
  'receive_title': 'চ্যাট ট্রান্সফার',
  'receive_steps':
      'পুরোনো ফোনে: সেটিংস → অ্যাকাউন্ট → চ্যাট ট্রান্সফার → কোড স্ক্যান করুন। তারপর এই কোডটি স্ক্যান করুন।',
  'receive_same_wifi': 'একই Wi-Fi ব্যবহার করুন। দুটি ফোনই খোলা রাখুন।',
  'receive_no_wifi': 'আগে এই ফোনটি Wi-Fi-তে যুক্ত করুন।',
  'receive_retry': 'আবার চেষ্টা করুন',
  'receive_error': 'শুরু করা গেল না। সংযোগ দেখে আবার চেষ্টা করুন।',
  'receiving': 'চ্যাট আসছে…',
  'importing': 'চ্যাট সেভ হচ্ছে…',
  'done_title': 'চ্যাট চলে এসেছে',
  'done_body': '{messages}টি মেসেজ ও {files}টি ফাইল এই ফোনে আছে।',
  'continue': 'চালিয়ে যান',
  'cancel': 'বাতিল',
  'encrypted_note': 'এনক্রিপ্টেড। AbabilX সার্ভার দিয়ে যায় না।',
  'send_title': 'চ্যাট পাঠানো হচ্ছে',
  'send_connecting': 'নতুন ফোনের সাথে যুক্ত হচ্ছে…',
  'send_sending': '{count}টি মেসেজ পাঠানো হচ্ছে…',
  'send_waiting': 'নতুন ডিভাইস {count}টি মেসেজ সেভ করছে…',
  'send_keep_open': 'দুটিই খোলা ও একই Wi-Fi-তে রাখুন।',
  'send_done': 'আপনার চ্যাট নতুন ডিভাইসে চলে গেছে।',
  'wipe_title': 'এই ফোন থেকে চ্যাট মুছবেন?',
  'wipe_body': 'মেসেজ ও ফাইল এই ফোন থেকে মুছে যাবে। আপনি সাইন ইন থাকবেন।',
  'wipe_keep': 'রেখে দিন',
  'wipe_delete': 'মুছুন',
  'wiped': 'এই ফোন থেকে চ্যাট মুছে ফেলা হয়েছে।',
  'close': 'বন্ধ',
  'settings_title': 'চ্যাট ট্রান্সফার',
  'screen_body': 'আপনার চ্যাট, ফাইল ও মেসেজ কী নতুন ফোন বা কম্পিউটারে নিন।',
  'step_new':
      'নতুন ফোন বা কম্পিউটারে AbabilX খুলে চ্যাট ট্রান্সফার বেছে নিন। সেখানে একটি কোড দেখাবে।',
  'step_wifi': 'দুটিকে একই Wi-Fi-তে যুক্ত করুন।',
  'step_scan': 'নিচে কোড স্ক্যান করুন চেপে সেই কোডটি স্ক্যান করুন।',
  'scan_button': 'কোড স্ক্যান করুন',
  'scan_title': 'কোডটি স্ক্যান করুন',
  'scan_hint': 'কোডটি আপনার নতুন ফোন বা কম্পিউটারে আছে।',
  'scan_computer_title': 'কম্পিউটারের কোড স্ক্যান করুন',
  'scan_computer_hint':
      'কম্পিউটারে: সেটিংস → Security → Transfer chats → Send chats।',
  'error_not_transfer':
      'এটি চ্যাট ট্রান্সফার কোড নয়। নতুন ফোন বা কম্পিউটারে দেখানো কোডটি স্ক্যান করুন।',
  'settings_sub': 'নতুন ফোন বা কম্পিউটারে চ্যাট নিন',
  'error_other_account': 'কোডটি অন্য অ্যাকাউন্টে সাইন ইন করা ডিভাইসের।',
  'from_computer': 'চ্যাট কম্পিউটারে? তার কোড স্ক্যান করুন',
  'error_pull_here':
      'এই কোড কম্পিউটারের চ্যাট নতুন ফোনে পাঠায়। নতুন ফোনের রিস্টোর স্ক্রিন থেকে স্ক্যান করুন।',
  'error_not_computer':
      'এটি কম্পিউটারের চ্যাট ট্রান্সফার কোড নয়। কম্পিউটারে সেটিংস → সিকিউরিটি → ফোনে চ্যাট পাঠান খুলুন।',
  'error_locked': 'এই ফোনে পাঠানোর মতো মেসেজ কী নেই।',
  'error_unreachable':
      'নতুন ফোন পাওয়া গেল না। দুটিকে একই Wi-Fi-তে রেখে আবার স্ক্যান করুন।',
  'error_refused': 'নতুন ফোন ট্রান্সফার থামিয়েছে। নতুন কোড স্ক্যান করুন।',
  'error_lost': 'সংযোগ বিচ্ছিন্ন হয়েছে। নতুন কোড স্ক্যান করে আবার শুরু করুন।',
  'error_wrong_account': 'এই চ্যাটগুলো অন্য অ্যাকাউন্টের।',
  'error_incomplete': 'ট্রান্সফার শেষ হওয়ার আগেই থেমে গেছে। আবার চেষ্টা করুন।',
  'error_no_space': 'এই ফোনে জায়গা শেষ।',
  'error_failed': 'ট্রান্সফার হয়নি। আবার চেষ্টা করুন।',
};
