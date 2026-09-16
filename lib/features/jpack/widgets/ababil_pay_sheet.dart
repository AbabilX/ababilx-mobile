import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/jpack_money.dart';
import '../providers/jpack_providers.dart';
import 'demo_balance_editor.dart';

/// Ababil Pay's confirm step: who, how much, what is left. Resolves true once
/// the user pays and the short "Ababil Pay" processing card has shown.
///
/// No money moves here — the caller debits. This sheet only asks.
Future<bool> showAbabilPaySheet(
  BuildContext context, {
  required String recipientName,
  required double amount,
}) async {
  final paid = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        _AbabilPaySheet(recipientName: recipientName, amount: amount),
  );
  if (paid != true || !context.mounted) return false;
  await _showProcessing(context);
  return true;
}

class AbabilPayMark extends StatelessWidget {
  const AbabilPayMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16A37F), Color(0xFF0B6E57)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '৳',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.58,
          height: 1,
        ),
      ),
    );
  }
}

class _AbabilPaySheet extends ConsumerWidget {
  const _AbabilPaySheet({required this.recipientName, required this.amount});

  final String recipientName;
  final double amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final balance = ref.watch(walletBalanceProvider).valueOrNull ?? 0;
    final enough = balance + 0.001 >= amount;

    Widget line(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AbabilPayMark(),
              const SizedBox(width: 8),
              Text(
                'Ababil Pay',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _DemoTag(label: t('jpack_demo')),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            formatTaka(amount, fixed: true),
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          line(t('jpack_pay_to'), recipientName),
          line(t('jpack_balance'), formatTaka(balance, fixed: true)),
          line(
            t('jpack_pay_balance_after'),
            formatTaka(enough ? balance - amount : balance, fixed: true),
            color: enough ? null : colors.error,
          ),
          if (!enough) ...[
            const SizedBox(height: 8),
            Text(
              t('jpack_insufficient'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.error),
            ),
            TextButton(
              onPressed: () => showDemoBalanceEditor(context),
              child: Text(t('jpack_edit_balance')),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A37F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: enough ? () => Navigator.of(context).pop(true) : null,
              child: Text(
                t(
                  'jpack_pay_button',
                ).replaceAll('{amount}', formatTaka(amount)),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoTag extends StatelessWidget {
  const _DemoTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.onTertiaryContainer),
      ),
    );
  }
}

/// The dark "Ababil Pay ···" card that sits over the screen while a payment
/// "processes" — the Weixin Pay moment in the reference screenshots.
Future<void> _showProcessing(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var open = true;
  unawaited(
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => const _ProcessingCard(),
    ).whenComplete(() => open = false),
  );
  await Future<void>.delayed(const Duration(milliseconds: 1300));
  if (open) navigator.pop();
}

class _ProcessingCard extends StatefulWidget {
  const _ProcessingCard();

  @override
  State<_ProcessingCard> createState() => _ProcessingCardState();
}

class _ProcessingCardState extends State<_ProcessingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: const Color(0xFF3A3A3C),
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 150,
          height: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AbabilPayMark(size: 44),
              const SizedBox(height: 14),
              const Text(
                'Ababil Pay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _dots,
                builder: (_, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(
                            alpha: (_dots.value * 3).floor() % 3 == i
                                ? 1
                                : 0.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
