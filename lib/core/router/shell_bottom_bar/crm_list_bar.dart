import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/crm/providers/crm_contacts_ui_provider.dart';
import '../../../features/crm/providers/crm_followups_ui_provider.dart';
import '../../../features/crm/providers/crm_leads_ui_provider.dart';
import '../../../features/crm/providers/crm_organizations_ui_provider.dart';
import '../../../features/search/crm_deep_search.dart';
import '../../localization/app_translations.dart';
import 'index.dart';

/// The bottom bar on a CRM list route: [My | Add | All] plus search, or the
/// Organizations variant, wired to whichever list is on screen.
class CrmListBottomBar extends ConsumerWidget {
  const CrmListBottomBar({
    super.key,
    required this.isLeads,
    required this.isFollowups,
    required this.isOrganizations,
  });

  final bool isLeads;
  final bool isFollowups;
  final bool isOrganizations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String label(String key) => AppTranslations.translate(context, ref, key);

    if (isOrganizations) {
      final ui = ref.watch(crmOrganizationsUiProvider);
      final notifier = ref.read(crmOrganizationsUiProvider.notifier);
      return ShellBottomBar(
        mode: ShellBottomBarMode.organizations,
        organizationsLabel: label('crm_organizations'),
        addLabel: label('crm_add_short'),
        canAdd: ui.canCreate,
        onAdd: notifier.requestAdd,
        onContactsSearch: notifier.requestSearch,
      );
    }

    final contactsUi = ref.watch(crmContactsUiProvider);
    final leadsUi = ref.watch(crmLeadsUiProvider);
    final followupsUi = ref.watch(crmFollowupsUiProvider);

    final mineSelected = isFollowups
        ? followupsUi.scope == FollowupScope.mine
        : isLeads
        ? leadsUi.scope == LeadScope.mine
        : contactsUi.scope == ContactScope.mine;
    final canAdd = isFollowups
        ? followupsUi.canCreate
        : isLeads
        ? leadsUi.canCreate
        : contactsUi.canCreate;

    return ShellBottomBar(
      mode: ShellBottomBarMode.contacts,
      contactsMineSelected: mineSelected,
      addLabel: label('crm_add_short'),
      mineLabel: label('crm_my_short'),
      allLabel: label('crm_all_short'),
      canAdd: canAdd,
      onAdd: () => _add(ref),
      onSelectMine: () => _setScope(ref, mine: true),
      onSelectAll: () => _setScope(ref, mine: false),
      onContactsSearch: () => openCrmDeepSearch(context, ref),
    );
  }

  void _add(WidgetRef ref) {
    if (isFollowups) {
      ref.read(crmFollowupsUiProvider.notifier)
        ..setFormSheetOpen(true)
        ..requestAdd();
    } else if (isLeads) {
      ref.read(crmLeadsUiProvider.notifier)
        ..setFormSheetOpen(true)
        ..requestAdd();
    } else {
      ref.read(crmContactsUiProvider.notifier)
        ..setFormSheetOpen(true)
        ..requestAdd();
    }
  }

  void _setScope(WidgetRef ref, {required bool mine}) {
    if (isFollowups) {
      ref
          .read(crmFollowupsUiProvider.notifier)
          .setScope(mine ? FollowupScope.mine : FollowupScope.all);
    } else if (isLeads) {
      ref
          .read(crmLeadsUiProvider.notifier)
          .setScope(mine ? LeadScope.mine : LeadScope.all);
    } else {
      ref
          .read(crmContactsUiProvider.notifier)
          .setScope(mine ? ContactScope.mine : ContactScope.all);
    }
  }
}
