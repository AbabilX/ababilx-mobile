import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_contact_detail_provider.dart';
import '../providers/crm_contacts_provider.dart';
import '../providers/crm_leads_provider.dart';
import '../providers/crm_leads_ui_provider.dart';
import '../shared/crm_money.dart';
import '../shared/crm_ui.dart';
import 'lead_form_sheet.dart';
import 'lead_row.dart';

/// Leads list — bar: [My|Add|All] + lead-only search pill.
class CrmLeadsPage extends ConsumerStatefulWidget {
  const CrmLeadsPage({super.key, this.contactId});

  /// When set (deep-link from contact), only that contact's leads.
  final String? contactId;

  @override
  ConsumerState<CrmLeadsPage> createState() => _CrmLeadsPageState();
}

class _CrmLeadsPageState extends ConsumerState<CrmLeadsPage> {
  var _busy = false;
  var _lastAddTick = 0;

  void _invalidate(String q) {
    ref.invalidate(crmLeadsProvider(q));
    final cid = widget.contactId;
    if (cid != null && cid.isNotEmpty) {
      ref.invalidate(crmContactLeadsProvider(cid));
    }
    ref.invalidate(crmConfigProvider);
    ref.invalidate(crmContactsProvider(''));
  }

  Future<void> _openForm({CrmLead? editing}) async {
    final ui = ref.read(crmLeadsUiProvider.notifier);
    ui.setFormSheetOpen(true);

    final config = await ref.read(crmConfigProvider.future);
    final detail = ref.read(teamGateProvider).valueOrNull;
    final perms = ref.read(crmPermsProvider);
    if (!mounted || detail == null) {
      ui.setFormSheetOpen(false);
      return;
    }

    List<CrmContact> contacts = const [];
    try {
      contacts = await ref.read(crmContactsProvider('').future);
    } catch (_) {}

    if (!mounted) {
      ui.setFormSheetOpen(false);
      return;
    }

    CrmLeadFormResult? result;
    try {
      result = await showLeadFormSheet(
        context,
        config: config,
        members: detail.members,
        contacts: contacts,
        canAssignOwner: detail.canAssignCrmOwner,
        canCreateContact: perms.create,
        initial: editing,
      );
    } finally {
      ui.setFormSheetOpen(false);
    }
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(crmRepositoryProvider);
      if (editing != null) {
        await repo.updateLead(editing.id, result.lead);
      } else {
        var contactId = result.contactId ?? '';
        if (result.newContact != null) {
          final created = await repo.createContact(result.newContact!);
          contactId = created.id;
        }
        if (contactId.isEmpty) {
          throw Exception('Contact required');
        }
        await repo.createLead(contactId, result.lead);
      }
      final q = ref.read(crmLeadsUiProvider).searchQuery;
      _invalidate(q);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(editing != null ? 'Lead updated' : 'Lead created'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(CrmLead lead) async {
    final colors = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${lead.title.isEmpty ? 'lead' : lead.title}?'),
        content: Text(
          AppTranslations.translate(context, ref, 'crm_delete_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppTranslations.translate(context, ref, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(crmRepositoryProvider).deleteLead(lead.id);
      final q = ref.read(crmLeadsUiProvider).searchQuery;
      _invalidate(q);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lead deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _syncShellMeta(List<CrmLead> all, String myId, bool canCreate) {
    final mine = all.where((l) => isMineLead(l, myId)).length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(crmLeadsUiProvider.notifier)
          .syncMeta(
            mineCount: mine,
            allCount: all.length,
            canCreate: canCreate,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final perms = ref.watch(crmPermsProvider);
    final ui = ref.watch(crmLeadsUiProvider);
    final configAsync = ref.watch(crmConfigProvider);
    final q = ui.searchQuery;
    final contactId = widget.contactId;
    final filterContact = contactId != null && contactId.isNotEmpty;
    final leadsAsync = filterContact
        ? ref.watch(crmContactLeadsProvider(contactId))
        : ref.watch(crmLeadsProvider(q));
    final myId = ref.watch(profileProvider).valueOrNull?.id ?? '';
    final currency = configAsync.valueOrNull?.settings.currency ?? 'BDT';

    ref.listen(crmLeadsUiProvider, (prev, next) {
      if (next.addTick != _lastAddTick &&
          (prev == null || next.addTick > prev.addTick)) {
        _lastAddTick = next.addTick;
        if (next.canCreate && !_busy) _openForm();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (filterContact) {
              context.go('/crm/contacts/$contactId');
            } else {
              context.go('/crm');
            }
          },
        ),
        title: Text(AppTranslations.translate(context, ref, 'crm_leads')),
        actions: [
          if (filterContact)
            IconButton(
              tooltip: 'Clear contact filter',
              onPressed: () => context.go('/crm/leads'),
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
          if (q.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: () =>
                  ref.read(crmLeadsUiProvider.notifier).setSearchQuery(''),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: Stack(
        children: [
          leadsAsync.when(
            loading: () => const CrmLoading(),
            error: (e, _) => CrmErrorBox(message: e.toString()),
            data: (all) {
              _syncShellMeta(all, myId, perms.create);
              final mine = all.where((l) => isMineLead(l, myId)).toList();
              var visible = ui.scope == LeadScope.mine ? mine : all;
              if (filterContact && q.isNotEmpty) {
                final lower = q.toLowerCase();
                visible = visible
                    .where(
                      (l) =>
                          l.title.toLowerCase().contains(lower) ||
                          (l.contactName ?? '').toLowerCase().contains(lower) ||
                          (l.ownerName ?? '').toLowerCase().contains(lower),
                    )
                    .toList();
              }
              if (visible.isEmpty) {
                final msg = q.isNotEmpty
                    ? 'No matches.'
                    : ui.scope == LeadScope.mine
                    ? AppTranslations.translate(
                        context,
                        ref,
                        'crm_leads_empty_mine',
                      )
                    : AppTranslations.translate(
                        context,
                        ref,
                        'crm_leads_empty_all',
                      );
                return CrmEmpty(message: msg);
              }
              return RefreshIndicator(
                onRefresh: () async => _invalidate(q),
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    ShellPillMetrics.contentBottom(context),
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final lead = visible[i];
                    return LeadRow(
                      lead: lead,
                      currency: currency,
                      config: configAsync.valueOrNull,
                      canUpdate: perms.update,
                      canDelete: perms.delete,
                      onTap: () => context.push('/crm/leads/${lead.id}'),
                      onEdit: () => _openForm(editing: lead),
                      onDelete: () => _delete(lead),
                    );
                  },
                ),
              );
            },
          ),
          if (_busy)
            ModalBarrier(
              dismissible: false,
              color: colors.scrim.withValues(alpha: 0.35),
            ),
          if (_busy)
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        ],
      ),
    );
  }
}
