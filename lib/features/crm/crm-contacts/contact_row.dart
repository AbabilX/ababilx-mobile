import 'package:flutter/material.dart';

import '../data/models/crm_models.dart';
import '../shared/crm_money.dart';

/// Flat list row — same density as conversation rows.
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
    final subtitle = [
      if (contact.company.isNotEmpty) contact.company,
      if (contact.email.isNotEmpty) contact.email,
    ].join(' · ');
    final meta = [
      if (contact.leadCount > 0) '${contact.leadCount} leads',
      if (contact.totalValue > 0)
        formatCrmMoney(contact.totalValue, currency),
      if (contact.ownerName != null && contact.ownerName!.isNotEmpty)
        contact.ownerName!,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      onLongPress: canUpdate ? onEdit : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (canDelete)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
