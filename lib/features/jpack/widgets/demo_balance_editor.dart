import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../providers/jpack_providers.dart';

/// Demo only: set the pretend Ababil Pay balance. Goes away with a real wallet.
Future<void> showDemoBalanceEditor(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _DemoBalanceEditor(),
    );

class _DemoBalanceEditor extends ConsumerStatefulWidget {
  const _DemoBalanceEditor();

  @override
  ConsumerState<_DemoBalanceEditor> createState() => _DemoBalanceEditorState();
}

class _DemoBalanceEditorState extends ConsumerState<_DemoBalanceEditor> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final current = ref.read(walletBalanceProvider).valueOrNull;
    if (current != null) {
      _ctrl.text = current == current.roundToDouble()
          ? current.toStringAsFixed(0)
          : current.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_ctrl.text.trim());
    if (value == null) return;
    await ref.read(walletBalanceProvider.notifier).setBalance(value);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('jpack_edit_balance'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            t('jpack_edit_balance_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d{0,9}(\.\d{0,2})?'),
              ),
            ],
            style: theme.textTheme.headlineSmall,
            decoration: const InputDecoration(
              prefixText: '৳ ',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(t('jpack_save'))),
        ],
      ),
    );
  }
}
