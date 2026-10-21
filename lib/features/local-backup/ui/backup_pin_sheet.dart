import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/backup_pin_store.dart';

/// Asks for the backup PIN (6 to 10 hex characters). [confirm] (setting it up) asks twice
/// and says it cannot be recovered; restoring asks once. Returns the PIN, or
/// null when dismissed. [error] is shown above the field (a wrong PIN).
Future<String?> showBackupPinSheet(
  BuildContext context, {
  required bool confirm,
  String? error,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _PinSheet(confirm: confirm, error: error),
);

class _PinSheet extends ConsumerStatefulWidget {
  const _PinSheet({required this.confirm, this.error});

  final bool confirm;
  final String? error;

  @override
  ConsumerState<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends ConsumerState<_PinSheet> {
  final _pin = TextEditingController();
  final _repeat = TextEditingController();
  late String? _error = widget.error;

  String t(String key) => AppTranslations.translate(context, ref, key);

  @override
  void dispose() {
    _pin.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _done() {
    if (!BackupPinStore.validPin(_pin.text)) {
      setState(() => _error = t('backup_pin_rule'));
      return;
    }
    if (widget.confirm && _repeat.text != _pin.text) {
      setState(() => _error = t('backup_pin_mismatch'));
      return;
    }
    Navigator.of(context).pop(BackupPinStore.normalize(_pin.text));
  }

  Widget _field(TextEditingController c, String label, {bool last = false}) =>
      TextField(
        controller: c,
        autofocus: c == _pin,
        obscureText: true,
        keyboardType: TextInputType.visiblePassword,
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
          LengthLimitingTextInputFormatter(BackupPinStore.maxLength),
        ],
        textAlign: TextAlign.center,
        // Hex only, so tracking cannot split Bangla text.
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(letterSpacing: 8),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => last ? _done() : null,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t(
              widget.confirm
                  ? 'backup_pin_set_title'
                  : 'backup_pin_enter_title',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t(widget.confirm ? 'backup_pin_set_body' : 'backup_pin_enter_body'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),
          _field(_pin, t('backup_pin_field'), last: !widget.confirm),
          if (widget.confirm) ...[
            const SizedBox(height: 12),
            _field(_repeat, t('backup_pin_repeat'), last: true),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _done, child: Text(t('backup_pin_continue'))),
        ],
      ),
    );
  }
}
