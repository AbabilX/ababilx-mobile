import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/chat_archive_wiper.dart';

// Do not let a server reset leave readable offline history or queued sends.
// Failures remain retryable in the reset dialog, without replacing the key again.
Future<void> clearFreshStartDevice(WidgetRef ref) async {
  await ref.read(chatArchiveWiperProvider).clear();
}
