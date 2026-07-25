import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/crm_money.dart';
import '../shared/stage_chip.dart';
import '../data/models/crm_models.dart';

/// Web `LeadCard` on contact detail.
class ContactLeadCard extends StatelessWidget {
  const ContactLeadCard({
    super.key,
    required this.lead,
    required this.currency,
    required this.canRemove,
    required this.removing,
    required this.onRemove,
  });

  final CrmLead lead;
  final String currency;
  final bool canRemove;
  final bool removing;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push('/crm/leads/${lead.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(14, 14, canRemove ? 40 : 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((lead.stageName ?? '').isNotEmpty)
                      StageChip(
                        name: lead.stageName!,
                        colorHex: lead.isLost ? '#EF4444' : lead.stageColor,
                      ),
                    const SizedBox(height: 10),
                    Text(
                      lead.title.isEmpty ? 'Untitled lead' : lead.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          lead.dealValue > 0
                              ? formatCrmMoney(lead.dealValue, currency)
                              : '—',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            (lead.ownerName ?? '').isEmpty
                                ? 'Unassigned'
                                : lead.ownerName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canRemove)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    tooltip: 'Remove lead',
                    onPressed: removing ? null : onRemove,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: colors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
