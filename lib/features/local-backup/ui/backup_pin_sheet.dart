import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../data/backup_pin_store.dart';

/// Asks for the backup PIN (6 to 32 characters of anything). [confirm] (setting it up) asks twice
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

  /// One eye for both fields: showing one and not its repeat helps nobody.
  bool _hidden = true;

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

  Widget _field(TextEditingController c, String label, {bool last = false}) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: c,
      autofocus: c == _pin,
      obscureText: _hidden,
      keyboardType: TextInputType.visiblePassword,
      autocorrect: false,
      enableSuggestions: false,
      // Any character; only the length is capped (code units, a little
      // above the rule's code-point limit so a Bangla PIN is not cut short).
      inputFormatters: [
        LengthLimitingTextInputFormatter(BackupPinStore.maxLength * 2),
      ],
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      style: Theme.of(context).textTheme.titleMedium,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          tooltip: t(_hidden ? 'backup_pin_show' : 'backup_pin_hide'),
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: HugeIcon(
            icon: _hidden
                ? HugeIcons.strokeRoundedView
                : HugeIcons.strokeRoundedViewOff,
            size: 22,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
      onSubmitted: (_) => last ? _done() : null,
    );
  }

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
