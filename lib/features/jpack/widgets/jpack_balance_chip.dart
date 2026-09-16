import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/jpack_money.dart';
import '../providers/jpack_providers.dart';
import 'ababil_pay_sheet.dart';
import 'demo_balance_editor.dart';

/// The Ababil Pay balance in an app bar. Tapping it edits the demo balance.
class JPackBalanceChip extends ConsumerWidget {
  const JPackBalanceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final balance = ref.watch(walletBalanceProvider).valueOrNull;
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showDemoBalanceEditor(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AbabilPayMark(size: 20),
              const SizedBox(width: 6),
              Text(
                balance == null ? '—' : formatTaka(balance),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.edit_rounded,
                size: 14,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
