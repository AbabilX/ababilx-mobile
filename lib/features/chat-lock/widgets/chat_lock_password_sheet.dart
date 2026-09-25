import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';

const chatLockPasswordMin = 4;
const chatLockPasswordMax = 64;

/// Asks for a new password for one chat, twice. Null when dismissed.
Future<String?> askNewChatLockPassword(BuildContext context, WidgetRef ref) =>
    _sheet(context, ref, confirm: true);

/// Asks for a chat's current password once. Null when dismissed.
Future<String?> askChatLockPassword(BuildContext context, WidgetRef ref) =>
    _sheet(context, ref, confirm: false);

Future<String?> _sheet(
  BuildContext context,
  WidgetRef ref, {
  required bool confirm,
}) => showModalBottomSheet<String>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _PasswordSheet(confirm: confirm),
);

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet({required this.confirm});

  final bool confirm;

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  String _t(String key) => AppTranslations.translate(context, ref, key);

  void _submit() {
    final password = _first.text;
    if (widget.confirm) {
      if (password.length < chatLockPasswordMin) {
        setState(() => _error = _t('chatlock_pw_too_short'));
        return;
      }
      if (password != _second.text) {
        setState(() => _error = _t('chatlock_pw_mismatch'));
        return;
      }
    } else if (password.isEmpty) {
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
          Text(
            _t(widget.confirm ? 'chatlock_pw_new_title' : 'chatlock_pw_title'),
            style: text.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            _t(widget.confirm ? 'chatlock_pw_new_body' : 'chatlock_pw_body'),
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          _field(_first, _t('chatlock_pw_field'), autofocus: true),
          if (widget.confirm) ...[
            const SizedBox(height: 10),
            _field(_second, _t('chatlock_pw_confirm_field')),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: Text(
              _t(widget.confirm ? 'chatlock_pw_save' : 'chatlock_continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool autofocus = false,
  }) => TextField(
    controller: controller,
    autofocus: autofocus,
    obscureText: true,
    enableSuggestions: false,
    autocorrect: false,
    enableIMEPersonalizedLearning: false,
    maxLength: chatLockPasswordMax,
    decoration: InputDecoration(
      labelText: label,
      counterText: '',
      border: const OutlineInputBorder(),
    ),
    onSubmitted: (_) => _submit(),
  );
}
