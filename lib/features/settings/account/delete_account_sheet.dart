import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/friendly_error.dart';
import '../../auth/providers/auth_provider.dart';

/// The word typed to confirm. Kept in English in both languages: it is a
/// deliberate act, not a translation exercise.
const _confirmWord = 'DELETE';

/// Settings → Account → Delete account. A bottom sheet that says what goes,
/// asks for the word typed out, then deletes on the server and wipes this
/// phone. Nothing happens on one tap.
Future<void> showDeleteAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _DeleteAccountSheet(),
  );
}

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() => _State();
}

class _State extends ConsumerState<_DeleteAccountSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).deleteAccount();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = serverErrorMessage(error) ??
            AppTranslations.translate(context, ref, 'delete_account_failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ready = _controller.text.trim().toUpperCase() == _confirmWord;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedDelete02,
            color: colors.error,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(t('delete_account'), style: text.titleLarge),
          const SizedBox(height: 12),
          for (final key in const [
            'delete_account_point_profile',
            'delete_account_point_phone',
            'delete_account_point_others',
            'delete_account_point_final',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '•  ${t(key)}',
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            t('delete_account_type').replaceAll('{word}', _confirmWord),
            style: text.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            enabled: !_busy,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: _confirmWord,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: ready && !_busy ? _delete : null,
              child: _busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onError,
                      ),
                    )
                  : Text(t('delete_account_confirm')),
            ),
          ),
        ],
      ),
    );
  }
}
