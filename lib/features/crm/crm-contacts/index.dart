import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_contacts_provider.dart';
import '../shared/crm_money.dart';
import '../shared/crm_ui.dart';
import 'contact_form_sheet.dart';
import 'contact_row.dart';
import 'contact_scope_tabs.dart';
import 'contact_search.dart';

/// Contacts list — web parity logic, app-native simple layout.
class CrmContactsPage extends ConsumerStatefulWidget {
  const CrmContactsPage({super.key});

  @override
  ConsumerState<CrmContactsPage> createState() => _CrmContactsPageState();
}

class _CrmContactsPageState extends ConsumerState<CrmContactsPage> {
  ContactScope _scope = ContactScope.mine;
  final _searchCtrl = TextEditingController();
  String _q = '';
  var _busy = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _invalidate() {
    ref.invalidate(crmContactsProvider(_q));
    ref.invalidate(crmConfigProvider);
  }

  Future<void> _openForm({CrmContact? editing}) async {
    final config = await ref.read(crmConfigProvider.future);
    final detail = ref.read(teamGateProvider).valueOrNull;
    if (!mounted || detail == null) return;

    final label = config.settings.contactLabelSingular;
    final body = await showContactFormSheet(
      context,
      config: config,
      members: detail.members,
      contactLabel: label,
      canAssignOwner: detail.canAssignCrmOwner,
      initial: editing,
    );
    if (body == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(crmRepositoryProvider);
      if (editing != null) {
        await repo.updateContact(editing.id, body);
      } else {
        await repo.createContact(body);
      }
      _invalidate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editing != null ? '$label updated' : '$label created',
          ),
        ),
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

  Future<void> _delete(CrmContact c, String labelSingular) async {
    final colors = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${c.name}?'),
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
      await ref.read(crmRepositoryProvider).deleteContact(c.id);
      _invalidate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$labelSingular deleted')),
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

  Widget _scopeTabs(List<CrmContact> all, String myId) {
    final mine = all.where((c) => isMineContact(c, myId)).toList();
    return ContactScopeTabs(
      scope: _scope,
      onScope: (s) => setState(() => _scope = s),
      mineCount: mine.length,
      allCount: all.length,
      mineLabel: AppTranslations.translate(context, ref, 'crm_my_contacts'),
      allLabel: AppTranslations.translate(context, ref, 'crm_all_contacts'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final perms = ref.watch(crmPermsProvider);
    final configAsync = ref.watch(crmConfigProvider);
    final contactsAsync = ref.watch(crmContactsProvider(_q));
    final myId = ref.watch(profileProvider).valueOrNull?.id ?? '';

    final settings = configAsync.valueOrNull?.settings ?? const CrmSettings();
    final labelPlural = settings.contactLabelPlural;
    final labelSingular = settings.contactLabelSingular;
    final currency = settings.currency;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(labelPlural),
        actions: [
          if (perms.create)
            IconButton(
              tooltip: 'New $labelSingular',
              onPressed: _busy ? null : () => _openForm(),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    contactsAsync.when(
                      data: (all) => _scopeTabs(all, myId),
                      loading: () => _scopeTabs(const [], myId),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 8),
                    ContactSearchField(
                      controller: _searchCtrl,
                      placeholder: AppTranslations.translate(
                        context,
                        ref,
                        'crm_search_contacts',
                      ),
                      onChanged: (v) => setState(() => _q = v.trim()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: contactsAsync.when(
                  loading: () => const CrmLoading(),
                  error: (e, _) => CrmErrorBox(message: e.toString()),
                  data: (all) {
                    final mine =
                        all.where((c) => isMineContact(c, myId)).toList();
                    final visible =
                        _scope == ContactScope.mine ? mine : all;
                    if (visible.isEmpty) {
                      final msg = _scope == ContactScope.mine
                          ? 'No ${labelPlural.toLowerCase()} assigned to you yet.'
                          : 'No ${labelPlural.toLowerCase()} yet.';
                      return CrmEmpty(message: msg);
                    }
                    return RefreshIndicator(
                      onRefresh: () async => _invalidate(),
                      child: ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: colors.outlineVariant.withValues(alpha: 0.5),
                        ),
                        itemBuilder: (_, i) {
                          final c = visible[i];
                          return ContactRow(
                            contact: c,
                            currency: currency,
                            canUpdate: perms.update,
                            canDelete: perms.delete,
                            onTap: () {
                              final msg = AppTranslations.translate(
                                context,
                                ref,
                                'crm_coming_soon',
                              );
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(content: Text(msg)),
                                );
                            },
                            onEdit: () => _openForm(editing: c),
                            onDelete: () => _delete(c, labelSingular),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
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
  }
}
