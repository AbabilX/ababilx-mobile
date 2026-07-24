import 'package:flutter/material.dart';

import '../crm-contacts/contact_badge.dart';
import '../data/models/crm_models.dart';
import '../shared/crm_money.dart';

/// Lead card — title, contact, stage, value, owner (web table columns).
class LeadRow extends StatelessWidget {
  const LeadRow({
    super.key,
    required this.lead,
    required this.currency,
    required this.canUpdate,
    required this.canDelete,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final CrmLead lead;
  final String currency;
  final bool canUpdate;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String get _initial {
    final n = lead.title.trim();
    if (n.isEmpty) {
      final c = (lead.contactName ?? '').trim();
      if (c.isEmpty) return '?';
      return c.substring(0, 1).toUpperCase();
    }
    return n.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtitle = [
      if ((lead.contactName ?? '').isNotEmpty) lead.contactName!,
      if ((lead.contactCompany ?? '').isNotEmpty) lead.contactCompany!,
    ].join(' · ');

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: canUpdate ? onEdit : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.65),
              width: 0.9,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: Text(
                    _initial,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.title.isEmpty
                            ? (lead.contactName ?? 'Untitled')
                            : lead.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if ((lead.stageName ?? '').isNotEmpty)
                            ContactBadge(
                              label: lead.stageName!,
                              tone: lead.isWon
                                  ? ContactBadgeTone.tertiary
                                  : lead.isLost
                                      ? ContactBadgeTone.error
                                      : ContactBadgeTone.primary,
                            ),
                          if (lead.dealValue > 0)
                            ContactBadge(
                              label: formatCrmMoney(lead.dealValue, currency),
                              tone: ContactBadgeTone.tertiary,
                            ),
                          if ((lead.ownerName ?? '').isNotEmpty)
                            ContactBadge(
                              label: lead.ownerName!,
                              tone: ContactBadgeTone.secondary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (canUpdate || canDelete)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: colors.onSurfaceVariant,
                      size: 20,
                    ),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      if (canUpdate)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                      if (canDelete)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
