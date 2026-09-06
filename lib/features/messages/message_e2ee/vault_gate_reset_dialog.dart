import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../../../core/localization/app_translations.dart';
import 'vault_reset_cleanup.dart';
import 'message_vault.dart';

/// "Start fresh": an emailed code, then a brand-new message identity for
/// somebody locked out of every device that held the old one, with no recovery
/// code either.
///
/// It states the loss before it asks for anything. Every existing message stays
/// sealed to a key nobody has, including us — that is not a bug to be softened
/// in the copy, it is what end-to-end encryption costs when the last copy of a
/// key is gone.
///
/// Returns the new recovery code on success, so the caller can show it.
class VaultGateResetDialog extends ConsumerStatefulWidget {
  const VaultGateResetDialog({super.key});

  static Future<String?> show(BuildContext context) => showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const VaultGateResetDialog(),
  );

  @override
  ConsumerState<VaultGateResetDialog> createState() => _State();
}

class _State extends ConsumerState<VaultGateResetDialog> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _saving = false;
  String _sentTo = '';
  String? _error;
  String? _recovery;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final sent = await ref
          .read(chatRepositoryProvider)
          .requestE2eeResetCode();
      if (!mounted) return;
      setState(() {
        _sentTo = (sent['email'] as String?) ?? '';
        _sending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'recovery_send_failed';
        _sending = false;
      });
    }
  }

  Future<void> _submit() async {
    final code = _controller.text.trim().toUpperCase();
    if (_saving) return;
    if (_recovery == null && !RegExp(r'^[0-9A-F]{9}$').hasMatch(code)) {
      setState(() => _error = 'recovery_email_invalid');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      _recovery ??= await ref
          .read(messageVaultProvider)
          .startFreshIdentity(code);
      await clearFreshStartDevice(ref);
      if (mounted) Navigator.of(context).pop(_recovery);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _recovery == null
            ? 'recovery_reset_failed'
            : 'recovery_clean_failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String t(String key) => AppTranslations.translate(context, ref, key);
    return PopScope(
      canPop: !_saving && _recovery == null,
      child: AlertDialog(
        title: Text(t('recovery_fresh')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('recovery_reset_body'), style: theme.textTheme.bodySmall),
              const SizedBox(height: 14),
              if (_sentTo.isEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _sending ? null : _requestCode,
                    child: Text(
                      t(_sending ? 'recovery_sending' : 'recovery_send'),
                    ),
                  ),
                )
              else ...[
                Text(
                  t('recovery_sent').replaceAll('{email}', _sentTo),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  enabled: !_saving && _recovery == null,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 9,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: t('recovery_email_hint'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  t(_error!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving || _sending || _recovery != null
                ? null
                : () => Navigator.of(context).pop(),
            child: Text(t('recovery_cancel')),
          ),
          if (_sentTo.isNotEmpty)
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(
                t(
                  _saving
                      ? 'recovery_saving'
                      : _recovery != null
                      ? 'recovery_continue'
                      : 'recovery_fresh',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
