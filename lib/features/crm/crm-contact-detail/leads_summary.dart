import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/crm_models.dart';
import '../shared/crm_hex_color.dart';

/// Web `LeadsSummary` — stage-colored pills jump to lead detail.
class LeadsSummary extends StatelessWidget {
  const LeadsSummary({super.key, required this.leads});

  final List<CrmLead> leads;

  @override
  Widget build(BuildContext context) {
    if (leads.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          height: 24,
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),
        Text(
          'Leads (${leads.length})',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final lead in leads)
              InkWell(
                onTap: () => context.push('/crm/leads/${lead.id}'),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: parseCrmHex(lead.stageColor) ?? colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          (lead.stageName ?? '').isEmpty
                              ? '—'
                              : lead.stageName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
