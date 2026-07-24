import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../messages/providers/team_gate_provider.dart';
import '../crm-contacts/contact_badge.dart';
import '../crm-leads/lead_form_sheet.dart';
import '../crm-leads/lead_row.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_contact_detail_provider.dart';
import '../providers/crm_contacts_provider.dart';
import '../providers/crm_leads_provider.dart';
import '../shared/crm_ui.dart';

/// Contact detail — header + leads list (web contact-detail).
class CrmContactDetailPage extends ConsumerStatefulWidget {
  const CrmContactDetailPage({super.key, required this.contactId});

  final String contactId;

  @override
  ConsumerState<CrmContactDetailPage> createState() =>
      _CrmContactDetailPageState();
}

class _CrmContactDetailPageState extends ConsumerState<CrmContactDetailPage> {
  var _busy = false;

  Future<void> _newLead(CrmContact contact) async {
    final config = await ref.read(crmConfigProvider.future);
    final detail = ref.read(teamGateProvider).valueOrNull;
    if (!mounted || detail == null) return;

    final result = await showLeadFormSheet(
      context,
      config: config,
      members: detail.members,
      contacts: [contact],
      canAssignOwner: detail.canAssignCrmOwner,
      canCreateContact: false,
      fixedContactId: contact.id,
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(crmRepositoryProvider).createLead(
            contact.id,
            result.lead,
          );
      invalidateContactDetail(ref, contact.id);
      ref.invalidate(crmLeadsProvider(''));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead created')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactAsync = ref.watch(crmContactProvider(widget.contactId));
    final leadsAsync = ref.watch(crmContactLeadsProvider(widget.contactId));
    final configAsync = ref.watch(crmConfigProvider);
    final perms = ref.watch(crmPermsProvider);
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final currency = configAsync.valueOrNull?.settings.currency ?? 'BDT';

    return contactAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: const CrmLoading(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: CrmErrorBox(message: e.toString()),
      ),
      data: (contact) {
        final meta = [
          if (contact.company.isNotEmpty) contact.company,
          if (contact.email.isNotEmpty) contact.email,
          if (contact.phone.isNotEmpty) contact.phone,
        ].join(' · ');

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/crm/contacts');
                }
              },
            ),
            title: Text(contact.name),
            actions: [
              if (perms.create)
                IconButton(
                  tooltip: 'New lead',
                  onPressed: _busy ? null : () => _newLead(contact),
                  icon: const Icon(Icons.add_rounded),
                ),
            ],
          ),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  invalidateContactDetail(ref, widget.contactId);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Text(
                      contact.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if ((contact.ownerName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Owner: ${contact.ownerName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'Leads',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.push(
                            '/crm/leads?contact=${contact.id}',
                          ),
                          child: const Text('All leads'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    leadsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                      error: (e, _) => CrmErrorBox(message: e.toString()),
                      data: (leads) {
                        if (leads.isEmpty) {
                          return const CrmEmpty(
                            message:
                                'No leads yet. Create one to start tracking a deal.',
                          );
                        }
                        return Column(
                          children: [
                            for (final lead in leads) ...[
                              LeadRow(
                                lead: lead,
                                currency: currency,
                                config: configAsync.valueOrNull,
                                canUpdate: false,
                                canDelete: false,
                                onTap: () =>
                                    context.push('/crm/leads/${lead.id}'),
                                onEdit: () {},
                                onDelete: () {},
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (_busy)
                ModalBarrier(
                  dismissible: false,
                  color: colors.scrim.withValues(alpha: 0.35),
                ),
              if (_busy)
                const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
            ],
          ),
        );
      },
    );
  }
}
