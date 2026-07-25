import 'package:flutter/material.dart';

import '../crm-contacts/contact_avatar.dart';
import '../crm-contacts/contact_badge.dart';
import '../crm-contacts/contact_type_label.dart';
import '../data/models/crm_models.dart';
import 'leads_summary.dart';

/// Web contact-header — avatar, type, name, designation, meta, tags, owner.
class ContactDetailHeader extends StatelessWidget {
  const ContactDetailHeader({
    super.key,
    required this.contact,
    required this.leads,
  });

  final CrmContact contact;
  final List<CrmLead> leads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final meta = [
      if (contact.company.isNotEmpty) contact.company,
      if (contact.email.isNotEmpty) contact.email,
      if (contact.phone.isNotEmpty) contact.phone,
    ];

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ContactAvatar(
                  name: contact.name,
                  imageUrl: contact.imageUrl,
                  radius: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contactTypeLabel(contact.contactType).toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (contact.designation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          contact.designation,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            for (final m in meta)
                              Text(
                                m,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (contact.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in contact.tags)
                              ContactBadge(
                                label: t,
                                tone: ContactBadgeTone.neutral,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if ((contact.ownerName ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      'Owner:\n${contact.ownerName}',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            LeadsSummary(leads: leads),
          ],
        ),
      ),
    );
  }
}
