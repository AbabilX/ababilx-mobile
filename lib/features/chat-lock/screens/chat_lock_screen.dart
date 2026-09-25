import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import '../data/chat_lock_index.dart';
import '../native/device_auth.dart';
import '../providers/chat_lock_session.dart';
import '../providers/chat_locks_provider.dart';
import '../widgets/chat_lock_actions.dart';

/// What stands in a locked chat's place until it is opened. Says nothing
/// about whose chat it is: no name, no picture — a notification tap or a
/// deep link lands here, and the person holding the phone may not be the
/// owner.
///
/// Phone lock prompts by itself once; a password chat waits for its password
/// and slows down after five wrong ones.
class ChatLockScreen extends ConsumerStatefulWidget {
  const ChatLockScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatLockScreen> createState() => _ChatLockScreenState();
}

class _ChatLockScreenState extends ConsumerState<ChatLockScreen> {
  final _password = TextEditingController();
  String? _error;
  bool _checking = false;
  int _wrong = 0;
  DateTime? _waitUntil;

  String _t(String key) => AppTranslations.translate(context, ref, key);

  ChatLockMethod? get _method =>
      ref.read(chatLockMethodProvider(widget.conversationId));

  @override
  void initState() {
    super.initState();
    if (_method == ChatLockMethod.device) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _device());
    }
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _open() =>
      ref.read(chatLockSessionProvider.notifier).unlock(widget.conversationId);

  Future<void> _device() async {
    if (!mounted) return;
    final result = await DeviceAuth.authenticate(
      title: _t('chatlock_prompt_title'),
    );
    if (!mounted) return;
    if (result == DeviceAuthResult.ok) {
      _open();
      return;
    }
    if (result == DeviceAuthResult.unavailable) {
      setState(() => _error = _t('chatlock_no_screen_lock_now'));
    }
  }

  Future<void> _submit() async {
    final wait = _waitUntil;
    if (wait != null && DateTime.now().isBefore(wait)) {
      setState(() => _error = _t('chatlock_pw_wait'));
      return;
    }
    if (_password.text.isEmpty || _checking) return;
    setState(() => _checking = true);
    final ok = await ref
        .read(chatLocksProvider.notifier)
        .verifyPassword(widget.conversationId, _password.text);
    if (!mounted) return;
    if (ok) {
      _open();
      return;
    }
    _wrong++;
    if (_wrong % 5 == 0) {
      _waitUntil = DateTime.now().add(const Duration(seconds: 30));
    }
    _password.clear();
    setState(() {
      _checking = false;
      _error = _t('chatlock_pw_wrong');
    });
  }

  Future<void> _forgot() async {
    final reset = await resetChatLockPassword(
      context,
      ref,
      widget.conversationId,
    );
    if (reset && mounted) _open();
  }

  @override
  Widget build(BuildContext context) {
    final method = ref.watch(chatLockMethodProvider(widget.conversationId));
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final password = method == ChatLockMethod.password;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/messages'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatIcon(
                  HugeIcons.strokeRoundedSquareLock02,
                  size: 56,
                  color: colors.primary,
                ),
                const SizedBox(height: 16),
                Text(_t('chatlock_locked_title'), style: text.titleLarge),
                const SizedBox(height: 8),
                Text(
                  _t(
                    password ? 'chatlock_enter_password' : 'chatlock_use_phone',
                  ),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (password)
                  TextField(
                    controller: _password,
                    autofocus: true,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    enableIMEPersonalizedLearning: false,
                    decoration: InputDecoration(
                      labelText: _t('chatlock_pw_field'),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: colors.error),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _checking
                        ? null
                        : password
                        ? _submit
                        : _device,
                    child: Text(_t('chatlock_unlock')),
                  ),
                ),
                if (password)
                  TextButton(
                    onPressed: _forgot,
                    child: Text(_t('chatlock_forgot')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
