import 'package:flutter/material.dart';

import '../crm-contacts/contact_badge.dart';
import '../data/models/crm_models.dart';
import '../shared/crm_money.dart';
import '../shared/stage_chip.dart';

/// Web DetailsPanel.
class FollowupDetailsPanel extends StatelessWidget {
  const FollowupDetailsPanel({
    super.key,
    required this.lead,
    required this.followup,
    required this.currency,
  });

  final CrmLead lead;
  final CrmFollowup followup;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget row(String label, Widget value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: value),
          ],
        ),
      );
    }

    Text text(String v) => Text(
      v,
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    return Column(
      children: [
        row('Lead', text(lead.title.isEmpty ? '—' : lead.title)),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        row(
          'Contact',
          text((lead.contactName ?? '').isEmpty ? '—' : lead.contactName!),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        row(
          'Company',
          text(
            (lead.contactCompany ?? '').isEmpty ? '—' : lead.contactCompany!,
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        row(
          'Phone',
          text((lead.contactPhone ?? '').isEmpty ? '—' : lead.contactPhone!),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        row(
          'Email',
          text((lead.contactEmail ?? '').isEmpty ? '—' : lead.contactEmail!),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        row('Source', text(lead.source.isEmpty ? '—' : lead.source)),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        row(
          'Stage',
          (lead.stageName ?? '').isEmpty
              ? text('—')
              : Align(
                  alignment: Alignment.centerLeft,
                  child: StageChip(
                    name: lead.stageName!,
                    colorHex: lead.stageColor,
                  ),
                ),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        row(
          'Deal value',
          text(
            lead.dealValue > 0 ? formatCrmMoney(lead.dealValue, currency) : '—',
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        row(
          'Type',
          text(
            (followup.activityTypeName ?? '').isEmpty
                ? '—'
                : followup.activityTypeName!,
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        row(
          'Priority',
          Align(
            alignment: Alignment.centerLeft,
            child: ContactBadge(
              label: followup.priority,
              tone: followup.priority == 'high'
                  ? ContactBadgeTone.error
                  : ContactBadgeTone.secondary,
            ),
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        row(
          'Assignee',
          text(
            (followup.assigneeName ?? '').isEmpty
                ? 'Unassigned'
                : followup.assigneeName!,
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        row('Notes', text(followup.notes.isEmpty ? '—' : followup.notes)),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        row('Outcome', text(followup.outcome.isEmpty ? '—' : followup.outcome)),
      ],
    );
  }
}
