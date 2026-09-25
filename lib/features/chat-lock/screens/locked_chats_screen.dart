import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/chat_lock_index.dart';
import '../native/device_auth.dart';
import '../providers/chat_lock_session.dart';
import '../providers/chat_locks_provider.dart';
import 'locked_chats_list.dart';
import 'locked_chats_unlock.dart';

/// The hidden list of locked chats, reached by a long press on the AbabilX
/// title in the chat list and nowhere else — the main list does not show a
/// folder row, so nothing on screen says locked chats exist.
///
/// Opens with the phone's own lock (and then opens every phone-lock chat
/// with it), or with any one chat's password (which opens that chat).
/// Leaving the list locks everything it opened again.
class LockedChatsScreen extends ConsumerStatefulWidget {
  const LockedChatsScreen({super.key});

  @override
  ConsumerState<LockedChatsScreen> createState() => _LockedChatsScreenState();
}

class _LockedChatsScreenState extends ConsumerState<LockedChatsScreen> {
  late final ChatLockSession _session;
  bool _phoneLock = false;
  bool _checking = false;
  String? _error;
  int _wrong = 0;
  DateTime? _waitUntil;

  String _t(String key) => AppTranslations.translate(context, ref, key);

  @override
  void initState() {
    super.initState();
    _session = ref.read(chatLockSessionProvider.notifier);
    DeviceAuth.available().then((available) {
      if (!mounted) return;
      setState(() => _phoneLock = available);
      if (available && !ref.read(chatLockSessionProvider).folderOpen) {
        _device();
      }
    });
  }

  @override
  void dispose() {
    scheduleMicrotask(_session.closeFolder);
    super.dispose();
  }

  Future<void> _device() async {
    final result = await DeviceAuth.authenticate(
      title: _t('chatlock_prompt_title'),
    );
    if (!mounted || result != DeviceAuthResult.ok) return;
    final locks = ref.read(chatLocksProvider);
    _session
      ..openFolder()
      ..unlockAll([
        for (final e in locks.entries)
          if (e.value == ChatLockMethod.device) e.key,
      ]);
  }

  Future<void> _password(String password) async {
    final wait = _waitUntil;
    if (wait != null && DateTime.now().isBefore(wait)) {
      setState(() => _error = _t('chatlock_pw_wait'));
      return;
    }
    if (password.isEmpty || _checking) return;
    setState(() => _checking = true);
    final locks = ref.read(chatLocksProvider);
    final notifier = ref.read(chatLocksProvider.notifier);
    for (final e in locks.entries) {
      if (e.value != ChatLockMethod.password) continue;
      if (await notifier.verifyPassword(e.key, password)) {
        if (!mounted) return;
        _session
          ..openFolder()
          ..unlock(e.key);
        setState(() => _checking = false);
        return;
      }
    }
    if (!mounted) return;
    _wrong++;
    if (_wrong % 5 == 0) {
      _waitUntil = DateTime.now().add(const Duration(seconds: 30));
    }
    setState(() {
      _checking = false;
      _error = _t('chatlock_pw_wrong');
    });
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
              error: _error,
              onPhoneLock: _device,
              onPassword: _password,
            ),
    );
  }
}
