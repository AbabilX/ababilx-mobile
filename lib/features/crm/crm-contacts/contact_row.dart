import 'package:flutter/material.dart';

import '../data/models/crm_models.dart';
import '../shared/crm_money.dart';
import 'contact_avatar.dart';
import 'contact_badge.dart';
import 'contact_type_label.dart';

/// Bordered contact card — avatar, type, designation (web contacts-table).
class ContactRow extends StatelessWidget {
  const ContactRow({
    super.key,
    required this.contact,
    required this.currency,
    required this.canUpdate,
    required this.canDelete,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final CrmContact contact;
  final String currency;
  final bool canUpdate;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtitle = contact.designation.isNotEmpty
        ? contact.designation
        : [
            if (contact.company.isNotEmpty) contact.company,
            if (contact.email.isNotEmpty) contact.email,
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
                ContactAvatar(
                  name: contact.name,
                  imageUrl: contact.imageUrl,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
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
                          ContactBadge(
                            label: contactTypeLabel(contact.contactType),
                            tone: ContactBadgeTone.secondary,
                          ),
                          ContactBadge(
                            label:
                                '${contact.leadCount} lead${contact.leadCount == 1 ? '' : 's'}',
                            tone: ContactBadgeTone.primary,
                          ),
                          if (contact.totalValue > 0)
                            ContactBadge(
                              label: formatCrmMoney(
                                contact.totalValue,
                                currency,
                              ),
                              tone: ContactBadgeTone.tertiary,
                            ),
                          if (contact.ownerName != null &&
                              contact.ownerName!.isNotEmpty)
                            ContactBadge(
                              label: contact.ownerName!,
                              tone: ContactBadgeTone.neutral,
                            ),
                          for (final tag in contact.tags.take(2))
                            ContactBadge(
                              label: tag,
                              tone: ContactBadgeTone.neutral,
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
