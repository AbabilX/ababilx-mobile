import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../crm-contacts/contact_form_sheet.dart';
import '../crm-leads/lead_form_sheet.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_contact_detail_provider.dart';
import '../providers/crm_contacts_provider.dart';
import '../providers/crm_leads_provider.dart';
import '../shared/crm_ui.dart';
import 'contact_header.dart';
import 'lead_card.dart';

/// Contact detail — header + leads (full web parity).
class CrmContactDetailPage extends ConsumerStatefulWidget {
  const CrmContactDetailPage({super.key, required this.contactId});

  final String contactId;

  @override
  ConsumerState<CrmContactDetailPage> createState() =>
      _CrmContactDetailPageState();
}

class _CrmContactDetailPageState extends ConsumerState<CrmContactDetailPage> {
  var _busy = false;
  String? _removingLeadId;

  Set<String> _initialStageIds(CrmConfig? config) {
    final ids = <String>{};
    for (final p in config?.pipelines ?? const <CrmPipeline>[]) {
      if (p.stages.isEmpty) continue;
      final sorted = [...p.stages]
        ..sort((a, b) => a.position.compareTo(b.position));
      ids.add(sorted.first.id);
    }
    return ids;
  }

  Future<void> _editContact(CrmContact contact) async {
    final config = await ref.read(crmConfigProvider.future);
    final organizations =
        await ref.read(crmRepositoryProvider).listOrganizationsOptional();
    final detail = ref.read(teamGateProvider).valueOrNull;
    if (!mounted || detail == null) return;

    final body = await showContactFormSheet(
      context,
      config: config,
      members: detail.members,
      contactLabel: config.settings.contactLabelSingular,
      canAssignOwner: detail.canAssignCrmOwner,
      organizations: organizations,
      initial: contact,
    );
    if (body == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(crmRepositoryProvider).updateContact(contact.id, body);
      invalidateContactDetail(ref, contact.id);
      ref.invalidate(crmContactsProvider(''));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contact updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteContact(CrmContact contact) async {
    final colors = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${contact.name}?'),
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
      await ref.read(crmRepositoryProvider).deleteContact(contact.id);
      ref.invalidate(crmContactsProvider(''));
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/crm/contacts');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
      await ref.read(crmRepositoryProvider).createLead(contact.id, result.lead);
      invalidateContactDetail(ref, contact.id);
      ref.invalidate(crmLeadsProvider(''));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lead created')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeLead(CrmLead lead) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove lead "${lead.title}"?'),
        content: const Text(
          'Only leads still on the initial pipeline stage can be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _removingLeadId = lead.id);
    try {
      await ref.read(crmRepositoryProvider).deleteLead(lead.id);
      invalidateContactDetail(ref, widget.contactId);
      ref.invalidate(crmLeadsProvider(''));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lead removed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _removingLeadId = null);
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
    final initialStages = _initialStageIds(configAsync.valueOrNull);

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
        final leads = leadsAsync.valueOrNull ?? const <CrmLead>[];

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
              if (perms.update || perms.delete)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _editContact(contact);
                    if (v == 'delete') _deleteContact(contact);
                  },
                  itemBuilder: (_) => [
                    if (perms.update)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (perms.delete)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
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
                    ContactDetailHeader(contact: contact, leads: leads),
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
                        if (perms.create)
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : () => _newLead(contact),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('New Lead'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    leadsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                      error: (e, _) => CrmErrorBox(message: e.toString()),
                      data: (list) {
                        if (list.isEmpty) {
                          return const CrmEmpty(
                            message:
                                'No leads yet. Create one to start tracking a deal.',
                          );
                        }
                        return Column(
                          children: [
                            for (final lead in list) ...[
                              ContactLeadCard(
                                lead: lead,
                                currency: currency,
                                canRemove:
                                    perms.delete &&
                                    lead.stageId != null &&
                                    initialStages.contains(lead.stageId),
                                removing: _removingLeadId == lead.id,
                                onRemove: () => _removeLead(lead),
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
