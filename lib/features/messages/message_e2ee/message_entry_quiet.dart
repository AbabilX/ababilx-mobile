import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../providers/chat_provider.dart';
import 'message_entry_ready.dart';
import 'message_vault.dart';

/// Once per process: a later visit to the check screen means the background
/// verify below found something, and that visit must run the full check.
bool _quietEntryTried = false;

/// A returning launch on a phone that already holds its key opens chats at
/// once; the server is asked afterwards, out of sight.
///
/// Every launch used to sit on "Checking your messages…" for a network round
/// trip whose answer is nearly always "this key is still current". Only local
/// storage is read, and it runs inside auth's own load (behind the launch
/// splash), so the router goes straight to chats and never paints the check
/// screen — not even blank. Call with a long-lived ref: the verify outlives it.
/// A pending restore (killed mid-run) or no local user id takes the full path.
Future<bool> tryQuietMessageEntry(Ref ref) async {
  if (_quietEntryTried) return false;
  _quietEntryTried = true;
  try {
    final userId = await ref.read(chatProvider.notifier).localUserId();
    if (userId.isEmpty) return false;
    final vault = ref.read(messageVaultProvider);
    if (await vault.hasPendingSession(userId)) return false;
    if (!await vault.restoreTrustedIdentityOffline()) return false;
    ref.read(messageEntryReadyProvider.notifier).state = true;
    unawaited(_verifyInBackground(ref));
    return true;
  } catch (_) {
    return false;
  }
}

/// Sends the user back to the check screen only on a real answer that the key
/// is no longer the account's. Offline, a policy refusal (the shell's own
/// overlay covers that) or any other failure keeps them in their chats.
Future<void> _verifyInBackground(Ref ref) async {
  final Map<String, dynamic> status;
  try {
    status = await ref.read(chatRepositoryProvider).getE2eeVault();
  } catch (_) {
    return;
  }
  final vault = ref.read(messageVaultProvider);
  final remote = status['vault'];
  final public = remote is Map ? remote['public_key'] : null;
  final current =
      status['exists'] == true &&
      public is Map &&
      await vault.adoptCurrentIdentity(Map<String, dynamic>.from(public));
  if (current) return;
  vault.lock();
  ref.read(messageEntryReadyProvider.notifier).state = false;
}
