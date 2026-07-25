import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_money.dart';
import '../shared/crm_ui.dart';

/// A small, ledger-first payment view: record an amount, then see what remains.
class PaymentsTab extends ConsumerWidget {
  const PaymentsTab({
    super.key,
    required this.lead,
    required this.payments,
    required this.currency,
    required this.canCreate,
    required this.canDelete,
  });

  final CrmLead lead;
  final List<CrmLeadPayment> payments;
  final String currency;
  final bool canCreate;
  final bool canDelete;

  bool get _closed => lead.isWon || lead.isLost;

  Future<void> _record(BuildContext context, WidgetRef ref, String kind) async {
    final input = await showModalBottomSheet<CrmLeadPaymentInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PaymentForm(
        maxAmount: kind == 'refund' ? lead.paidValue : lead.outstandingValue,
        kind: kind,
      ),
    );
    if (input == null) return;
    try {
      await ref.read(crmRepositoryProvider).createLeadPayment(lead.id, input);
      invalidateLeadDetail(ref, lead.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.translate(context, ref, 'crm_save_payment'),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(crmRepositoryProvider).deleteLeadPayment(id);
      invalidateLeadDetail(ref, lead.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final closed = _closed;
    final canAdd = canCreate && !closed && lead.outstandingValue > 0.005;
    final canRefund = canCreate && !closed && lead.paidValue > 0.005;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: _MoneyMetric(
                label: AppTranslations.translate(context, ref, 'crm_paid'),
                value: formatCrmMoney(lead.paidValue, currency),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MoneyMetric(
                label: lead.outstandingValue > 0.005
                    ? AppTranslations.translate(context, ref, 'crm_remaining')
                    : AppTranslations.translate(
                        context,
                        ref,
                        'crm_payment_complete',
                      ),
                value: formatCrmMoney(lead.outstandingValue, currency),
                emphasis: lead.outstandingValue <= 0.005,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (closed)
          Text(
            AppTranslations.translate(context, ref, 'crm_payment_locked'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            children: [
              if (canAdd)
                FilledButton.icon(
                  onPressed: () => _record(context, ref, 'payment'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    AppTranslations.translate(context, ref, 'crm_add_payment'),
                  ),
                ),
              if (canRefund)
                OutlinedButton(
                  onPressed: () => _record(context, ref, 'refund'),
                  child: Text(
                    AppTranslations.translate(context, ref, 'crm_refund'),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        if (payments.isEmpty)
          const CrmEmpty(message: '—')
        else
          for (final payment in payments)
            _PaymentRow(
              payment: payment,
              currency: currency,
              canDelete: canDelete && !closed,
              onDelete: () => _delete(context, ref, payment.id),
            ),
      ],
    );
  }
}

class _MoneyMetric extends StatelessWidget {
  const _MoneyMetric({
    required this.label,
    required this.value,
    this.emphasis = false,
  });
  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: emphasis ? colors.primary : null,
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.currency,
    required this.canDelete,
    required this.onDelete,
  });
  final CrmLeadPayment payment;
  final String currency;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        payment.isRefund ? Icons.undo_rounded : Icons.payments_outlined,
        color: payment.isRefund ? colors.error : colors.primary,
      ),
      title: Text(
        '${payment.isRefund ? '−' : '+'}${formatCrmMoney(payment.amount, currency)}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        [
          formatCrmDateTime(payment.paidAt),
          if (payment.method.isNotEmpty) payment.method,
          if (payment.reference.isNotEmpty) payment.reference,
        ].join(' · '),
      ),
      trailing: canDelete
          ? IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, color: colors.error),
            )
          : null,
    );
  }
}

class _PaymentForm extends ConsumerStatefulWidget {
  const _PaymentForm({required this.maxAmount, required this.kind});
  final double maxAmount;
  final String kind;

  @override
  ConsumerState<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<_PaymentForm> {
  final _amount = TextEditingController();
  final _method = TextEditingController();
  final _reference = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _method.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0 || amount > widget.maxAmount + 0.005) return;
    Navigator.pop(
      context,
      CrmLeadPaymentInput(
        kind: widget.kind,
        amount: amount,
        paidAt: DateTime.now().toUtc().toIso8601String(),
        method: _method.text.trim(),
        reference: _reference.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final max = widget.maxAmount.toStringAsFixed(
      widget.maxAmount == widget.maxAmount.roundToDouble() ? 0 : 2,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppTranslations.translate(
              context,
              ref,
              widget.kind == 'refund' ? 'crm_refund' : 'crm_record_payment',
            ),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: AppTranslations.translate(
                context,
                ref,
                'crm_payment_amount',
              ),
              helperText: '≤ $max',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _method,
            decoration: InputDecoration(
              labelText: AppTranslations.translate(
                context,
                ref,
                'crm_payment_method',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reference,
            decoration: InputDecoration(
              labelText: AppTranslations.translate(
                context,
                ref,
                'crm_payment_reference',
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(backgroundColor: colors.primary),
            child: Text(
              AppTranslations.translate(context, ref, 'crm_save_payment'),
            ),
          ),
        ],
      ),
    );
  }
}
