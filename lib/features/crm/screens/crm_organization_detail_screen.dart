import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/root_back.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../crm-organizations/organization_form_sheet.dart';
import '../crm-organizations/organization_documents.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_contacts_provider.dart';
import '../providers/crm_organizations_provider.dart';
import '../shared/crm_money.dart';
import '../shared/crm_ui.dart';
import '../shared/stage_chip.dart';

class CrmOrganizationDetailScreen extends ConsumerWidget {
  const CrmOrganizationDetailScreen({super.key, required this.organizationId});

  final String organizationId;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CrmOrganization organization,
  ) async {
    final team = ref.read(teamGateProvider).valueOrNull;
    if (team == null) return;
    final result = await showOrganizationFormSheet(
      context,
      members: team.members,
      canAssignOwner: team.canAssignCrmOwner,
      canCreateContact: false,
      initial: organization,
    );
    if (result == null) return;
    await ref
        .read(crmRepositoryProvider)
        .updateOrganization(organization.id, result.organization);
    ref.invalidate(crmOrganizationProvider(organization.id));
    ref.invalidate(crmOrganizationsProvider(''));
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    CrmOrganization organization,
  ) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Remove organization'),
              subtitle: Text(
                'Choose how linked contacts and leads are handled.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              subtitle: const Text('Keep its full history together.'),
              onTap: () => Navigator.pop(sheetContext, 'archive'),
            ),
            ListTile(
              leading: const Icon(Icons.link_off_rounded),
              title: const Text('Remove organization only'),
              subtitle: const Text(
                'Contacts become independent; leads remain.',
              ),
              onTap: () => Navigator.pop(sheetContext, 'detach'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: const Text('Delete everything after 7 days'),
              subtitle: const Text('Restorable during the safety window.'),
              onTap: () => Navigator.pop(sheetContext, 'cascade'),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !context.mounted) return;
    await ref
        .read(crmRepositoryProvider)
        .removeOrganization(organization.id, mode);
    ref.invalidate(crmOrganizationsProvider(''));
    if (context.mounted) context.go('/crm/organizations');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamGateProvider);
    if (team.isLoading) {
      return const Scaffold(body: CrmLoading());
    }
    if (team.valueOrNull?.canViewCrm != true) {
      return const Scaffold(body: CrmEmpty(message: 'CRM access is required.'));
    }
    final organization = ref.watch(crmOrganizationProvider(organizationId));
    final contacts = ref.watch(crmOrganizationContactsProvider(organizationId));
    final leads = ref.watch(crmOrganizationLeadsProvider(organizationId));
    final perms = ref.watch(crmPermsProvider);
    final currency =
        ref.watch(crmConfigProvider).valueOrNull?.settings.currency ?? 'BDT';
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return organization.when(
      loading: () => const Scaffold(body: CrmLoading()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: CrmErrorBox(message: error.toString()),
      ),
      data: (record) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => popOrGoHome(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: Text(record.name),
            actions: [
              if (perms.update)
                IconButton(
                  onPressed: () => _edit(context, ref, record),
                  icon: const Icon(Icons.edit_outlined),
                ),
              if (perms.delete)
                PopupMenuButton<String>(
                  onSelected: (_) => _remove(context, ref, record),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove organization'),
                    ),
                  ],
                ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Contacts'),
                Tab(text: 'Leads'),
                Tab(text: 'Documents'),
              ],
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                      child: const Icon(Icons.business_rounded),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            [
                              if (record.industry.isNotEmpty) record.industry,
                              record.status,
                              if ((record.ownerName ?? '').isNotEmpty)
                                record.ownerName!,
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    _Metric(
                      label: 'Pipeline',
                      value: formatCrmMoney(record.pipelineValue, currency),
                    ),
                    _Metric(
                      label: 'Won',
                      value: formatCrmMoney(record.wonValue, currency),
                    ),
                    _Metric(
                      label: 'Collected',
                      value: formatCrmMoney(record.paidValue, currency),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              Expanded(
                child: TabBarView(
                  children: [
                    _Overview(record: record),
                    contacts.when(
                      loading: () => const CrmLoading(),
                      error: (error, _) =>
                          CrmErrorBox(message: error.toString()),
                      data: (items) => items.isEmpty
                          ? const CrmEmpty(message: 'No linked contacts.')
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) => ListTile(
                                onTap: () => context.push(
                                  '/crm/contacts/${items[i].id}',
                                ),
                                title: Text(items[i].name),
                                subtitle: Text(
                                  [
                                    items[i].designation,
                                    items[i].organizationRole,
                                    items[i].email,
                                  ].where((e) => e.isNotEmpty).join(' · '),
                                ),
                                trailing: items[i].isPrimaryContact
                                    ? const Icon(Icons.star_rounded)
                                    : const Icon(Icons.chevron_right_rounded),
                              ),
                            ),
                    ),
                    leads.when(
                      loading: () => const CrmLoading(),
                      error: (error, _) =>
                          CrmErrorBox(message: error.toString()),
                      data: (items) => items.isEmpty
                          ? const CrmEmpty(message: 'No organization leads.')
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) => ListTile(
                                onTap: () =>
                                    context.push('/crm/leads/${items[i].id}'),
                                title: Text(items[i].title),
                                subtitle: Text(items[i].contactName ?? ''),
                                trailing: StageChip(
                                  name: items[i].stageName ?? '',
                                  colorHex: items[i].stageColor,
                                ),
                              ),
                            ),
                    ),
                    OrganizationDocuments(
                      organizationId: record.id,
                      canCreate: perms.create,
                      canDelete: perms.delete,
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.record});
  final CrmOrganization record;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Website', record.website),
      ('Email', record.email),
      ('Phone', record.phone),
      ('Address', record.address),
      ('Source', record.source),
      ('Brands', record.tags.join(', ')),
      ('Description', record.description),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final row in rows)
          if (row.$2.isNotEmpty)
            ListTile(title: Text(row.$1), subtitle: Text(row.$2)),
      ],
    );
  }
}
