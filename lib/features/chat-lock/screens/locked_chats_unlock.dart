import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';

/// The locked-chats list before it is opened. Shows how to unlock — phone
/// lock or a chat password — and opens a bottom sheet only after the person
/// picks one. Never prompts the system lock on its own: that would fire
/// the moment the screen opened.
class LockedChatsUnlock extends ConsumerWidget {
  const LockedChatsUnlock({
    super.key,
    required this.phoneLock,
    required this.checking,
    required this.onPhoneLock,
    required this.onPassword,
  });

  final bool phoneLock;
  final bool checking;
  final Future<void> Function() onPhoneLock;
  final Future<bool> Function(String password) onPassword;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChatIcon(
                HugeIcons.strokeRoundedSquareLock02,
                size: 56,
                color: colors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                t('chatlock_folder_body'),
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              if (phoneLock)
                ListTile(
                  enabled: !checking,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  leading: const ChatIcon(HugeIcons.strokeRoundedFingerPrint),
                  title: Text(t('chatlock_opt_device')),
                  subtitle: Text(t('chatlock_opt_device_sub')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openPhoneSheet(context, ref),
                ),
              if (phoneLock) const SizedBox(height: 12),
              ListTile(
                enabled: !checking,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                leading: const ChatIcon(HugeIcons.strokeRoundedLockPassword),
                title: Text(t('chatlock_opt_password')),
                subtitle: Text(t('chatlock_folder_password_sub')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openPasswordSheet(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPhoneSheet(BuildContext context, WidgetRef ref) async {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final go = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheet) {
        final colors = Theme.of(sheet).colorScheme;
        final text = Theme.of(sheet).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t('chatlock_opt_device'), style: text.titleLarge),
                const SizedBox(height: 6),
                Text(
                  t('chatlock_folder_phone_sheet_body'),
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.of(sheet).pop(true),
                  icon: const ChatIcon(HugeIcons.strokeRoundedFingerPrint),
                  label: Text(t('chatlock_use_phone_lock')),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (go == true) await onPhoneLock();
  }

  Future<void> _openPasswordSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FolderPasswordSheet(onPassword: onPassword),
    );
  }
}

class _FolderPasswordSheet extends ConsumerStatefulWidget {
  const _FolderPasswordSheet({required this.onPassword});

  final Future<bool> Function(String password) onPassword;

  @override
  ConsumerState<_FolderPasswordSheet> createState() =>
      _FolderPasswordSheetState();
}

class _FolderPasswordSheetState extends ConsumerState<_FolderPasswordSheet> {
  final _password = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  String _t(String key) => AppTranslations.translate(context, ref, key);

  Future<void> _submit() async {
    final value = _password.text;
    if (value.isEmpty || _checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await widget.onPassword(value);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    _password.clear();
    setState(() {
      _checking = false;
      _error = _t('chatlock_pw_wrong');
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_t('chatlock_pw_title'), style: text.titleLarge),
          const SizedBox(height: 6),
          Text(
            _t('chatlock_folder_password_sheet_body'),
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            autofocus: true,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(
              labelText: _t('chatlock_folder_password'),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: text.bodySmall?.copyWith(color: colors.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _checking ? null : _submit,
            child: _checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_t('chatlock_unlock')),
          ),
        ],
      ),
    );
  }
}
