import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';

/// The locked-chats list before it is opened: the phone's lock, or any
/// locked chat's password.
class LockedChatsUnlock extends ConsumerStatefulWidget {
  const LockedChatsUnlock({
    super.key,
    required this.phoneLock,
    required this.checking,
    required this.error,
    required this.onPhoneLock,
    required this.onPassword,
  });

  final bool phoneLock;
  final bool checking;
  final String? error;
  final VoidCallback onPhoneLock;
  final ValueChanged<String> onPassword;

  @override
  ConsumerState<LockedChatsUnlock> createState() => _LockedChatsUnlockState();
}

class _LockedChatsUnlockState extends ConsumerState<LockedChatsUnlock> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _password.text;
    _password.clear();
    widget.onPassword(value);
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
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
              Text(
                t('chatlock_folder_body'),
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              if (widget.phoneLock) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.checking ? null : widget.onPhoneLock,
                    icon: const ChatIcon(HugeIcons.strokeRoundedFingerPrint),
                    label: Text(t('chatlock_use_phone_lock')),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              TextField(
                controller: _password,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                enableIMEPersonalizedLearning: false,
                decoration: InputDecoration(
                  labelText: t('chatlock_folder_password'),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (widget.error != null) ...[
                const SizedBox(height: 10),
                Text(
                  widget.error!,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.checking ? null : _submit,
                  child: widget.checking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t('chatlock_unlock')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
