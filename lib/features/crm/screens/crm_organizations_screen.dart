import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/friendly_error.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../crm-organizations/organization_form_sheet.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_contacts_provider.dart';
import '../providers/crm_organizations_provider.dart';
import '../providers/crm_organizations_ui_provider.dart';
import '../shared/crm_money.dart';
import '../shared/crm_ui.dart';

class CrmOrganizationsScreen extends ConsumerStatefulWidget {
  const CrmOrganizationsScreen({super.key});

  @override
  ConsumerState<CrmOrganizationsScreen> createState() =>
      _CrmOrganizationsScreenState();
}

class _CrmOrganizationsScreenState
    extends ConsumerState<CrmOrganizationsScreen> {
  final _search = TextEditingController();
  var _query = '';
  var _showSearch = false;
  var _lastAddTick = 0;
  var _lastSearchTick = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _form([CrmOrganization? initial]) async {
    final ui = ref.read(crmOrganizationsUiProvider.notifier);
    ui.setFormSheetOpen(true);
    final team = ref.read(teamGateProvider).valueOrNull;
    if (team == null) {
      ui.setFormSheetOpen(false);
      return;
    }
    OrganizationFormResult? result;
    try {
      result = await showOrganizationFormSheet(
        context,
        members: team.members,
        canAssignOwner: team.canAssignCrmOwner,
        canCreateContact: initial == null && ref.read(crmPermsProvider).create,
        initial: initial,
      );
    } finally {
      ui.setFormSheetOpen(false);
    }
    if (result == null) return;
    final repo = ref.read(crmRepositoryProvider);
    if (initial == null) {
      final organization = await repo.createOrganization(result.organization);
      for (final contact in result.contacts) {
        await repo.createContact(
          CrmContactInput(
            name: contact.name,
            designation: contact.designation,
            email: contact.email,
            phone: contact.phone,
            organizationId: organization.id,
            company: organization.name,
            isPrimaryContact: contact.isPrimaryContact,
          ),
        );
      }
      if (result.contacts.isNotEmpty) ref.invalidate(crmContactsProvider(''));
    } else {
      await repo.updateOrganization(initial.id, result.organization);
    }
    ref.invalidate(crmOrganizationsProvider(_query));
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(crmPermsProvider);
    final organizations = ref.watch(crmOrganizationsProvider(_query));
    final currency =
        ref.watch(crmConfigProvider).valueOrNull?.settings.currency ?? 'BDT';
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final ui = ref.watch(crmOrganizationsUiProvider);

    ref.listen(crmOrganizationsUiProvider, (previous, next) {
      if (next.addTick != _lastAddTick &&
          (previous == null || next.addTick > previous.addTick)) {
        _lastAddTick = next.addTick;
        if (next.canCreate) _form();
      }
      if (next.searchTick != _lastSearchTick &&
          (previous == null || next.searchTick > previous.searchTick)) {
        _lastSearchTick = next.searchTick;
        setState(() => _showSearch = true);
      }
    });
    if (ui.canCreate != perms.create) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(crmOrganizationsUiProvider.notifier)
              .setCanCreate(perms.create);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/crm'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: _showSearch
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search organizations',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              )
            : const Text('Organizations'),
        actions: [
          if (_showSearch)
            IconButton(
              onPressed: () => setState(() {
                _showSearch = false;
                _search.clear();
                _query = '';
              }),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: organizations.when(
        loading: () => const CrmLoading(),
        error: (error, _) => CrmErrorBox(message: friendlyErrorMessage(error)),
        data: (items) => items.isEmpty
            ? const CrmEmpty(message: 'No organizations yet.')
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(crmOrganizationsProvider(_query)),
                child: ListView.separated(
                  padding: EdgeInsets.only(
                    bottom: ShellPillMetrics.contentBottom(context),
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 72,
                    color: colors.outlineVariant,
                  ),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final subtitle = item.website.isNotEmpty
                        ? item.website
                        : item.industry;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      onTap: () =>
                          context.push('/crm/organizations/${item.id}'),
                      leading: CircleAvatar(
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                        child: item.logoUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  item.logoUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.business_rounded),
                      ),
                      title: Text(
                        item.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (subtitle.isNotEmpty) subtitle,
                          '${item.contactCount} contacts',
                          '${item.leadCount} leads',
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item.status,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          if (item.pipelineValue > 0)
                            Text(
                              formatCrmMoney(item.pipelineValue, currency),
                              style: theme.textTheme.labelMedium,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
