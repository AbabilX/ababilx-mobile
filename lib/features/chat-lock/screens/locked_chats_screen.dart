import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/chat_lock_index.dart';
import '../native/device_auth.dart';
import '../providers/chat_lock_session.dart';
import '../providers/chat_locks_provider.dart';
import 'locked_chats_list.dart';
import 'locked_chats_unlock.dart';

/// The hidden list of locked chats, reached by a long press on the AbabilX
/// title in the chat list or from Settings → Locked chats — the main list
/// does not show a folder row, so nothing there says locked chats exist.
///
/// The person picks phone lock or a chat password first; only then does a
/// bottom sheet (and, for phone lock, the system prompt) appear. Opens with
/// the phone's own lock (revealing every phone-lock chat), or with a chat
/// password (revealing every chat that accepted that password — never one
/// locked under a different password). Leaving the list locks everything it
/// opened again.
class LockedChatsScreen extends ConsumerStatefulWidget {
  const LockedChatsScreen({super.key});

  @override
  ConsumerState<LockedChatsScreen> createState() => _LockedChatsScreenState();
}

class _LockedChatsScreenState extends ConsumerState<LockedChatsScreen> {
  late final ChatLockSession _session;
  bool _phoneLock = false;
  bool _checking = false;
  int _wrong = 0;
  DateTime? _waitUntil;

  String _t(String key) => AppTranslations.translate(context, ref, key);

  @override
  void initState() {
    super.initState();
    _session = ref.read(chatLockSessionProvider.notifier);
    // Availability only — never call DeviceAuth here. The system prompt
    // must wait until the person picks "Phone lock" in the sheet.
    DeviceAuth.available().then((available) {
      if (!mounted) return;
      setState(() => _phoneLock = available);
    });
  }

  @override
  void dispose() {
    scheduleMicrotask(_session.closeFolder);
    super.dispose();
  }

  Future<void> _device() async {
    setState(() => _checking = true);
    final result = await DeviceAuth.authenticate(
      title: _t('chatlock_prompt_title'),
    );
    if (!mounted) return;
    setState(() => _checking = false);
    if (result != DeviceAuthResult.ok) return;
    final locks = ref.read(chatLocksProvider);
    // Phone lock reveals only chats that use the phone lock — never a
    // password chat, or typing any one password would be pointless.
    _session.openFolderWith([
      for (final e in locks.entries)
        if (e.value == ChatLockMethod.device) e.key,
    ]);
  }

  /// True when at least one chat accepted [password].
  Future<bool> _password(String password) async {
    final wait = _waitUntil;
    if (wait != null && DateTime.now().isBefore(wait)) {
      if (mounted) {
        showAppToast(context, _t('chatlock_pw_wait'), isError: true);
      }
      return false;
    }
    if (password.isEmpty) return false;
    final locks = ref.read(chatLocksProvider);
    final notifier = ref.read(chatLocksProvider.notifier);
    // Every chat that accepted this password — two chats with the same
    // password open together; a different password's chat stays hidden.
    final matched = <String>[];
    for (final e in locks.entries) {
      if (e.value != ChatLockMethod.password) continue;
      if (await notifier.verifyPassword(e.key, password)) {
        matched.add(e.key);
      }
    }
    if (!mounted) return false;
    if (matched.isNotEmpty) {
      _session.openFolderWith(matched);
      return true;
    }
    _wrong++;
    if (_wrong % 5 == 0) {
      _waitUntil = DateTime.now().add(const Duration(seconds: 30));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(chatLockSessionProvider.select((s) => s.folderOpen));
    return Scaffold(
      appBar: AppBar(title: Text(_t('chatlock_folder_title'))),
      body: open
          ? const LockedChatsList()
          : LockedChatsUnlock(
              phoneLock: _phoneLock,
              checking: _checking,
              onPhoneLock: _device,
              onPassword: _password,
            ),
    );
  }
}
