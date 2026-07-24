import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_contacts_provider.dart';
import '../providers/crm_contacts_ui_provider.dart';
import '../shared/crm_money.dart';
import '../shared/crm_ui.dart';
import 'contact_form_sheet.dart';
import 'contact_row.dart';
import 'contact_search.dart';

/// Contacts list — scope/add live in [ContactsShellBar] (home-style pills).
class CrmContactsPage extends ConsumerStatefulWidget {
  const CrmContactsPage({super.key});

  @override
  ConsumerState<CrmContactsPage> createState() => _CrmContactsPageState();
}

class _CrmContactsPageState extends ConsumerState<CrmContactsPage> {
  final _searchCtrl = TextEditingController();
  String _q = '';
  var _busy = false;
  var _lastAddTick = 0;

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

  void _syncShellMeta(List<CrmContact> all, String myId, bool canCreate) {
    final mine = all.where((c) => isMineContact(c, myId)).length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(crmContactsUiProvider.notifier).syncMeta(
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
    final ui = ref.watch(crmContactsUiProvider);
    final configAsync = ref.watch(crmConfigProvider);
    final contactsAsync = ref.watch(crmContactsProvider(_q));
    final myId = ref.watch(profileProvider).valueOrNull?.id ?? '';

    final settings = configAsync.valueOrNull?.settings ?? const CrmSettings();
    final labelPlural = settings.contactLabelPlural;
    final labelSingular = settings.contactLabelSingular;
    final currency = settings.currency;

    // Bottom-bar Add pill → open create sheet.
    ref.listen(crmContactsUiProvider, (prev, next) {
      if (next.addTick == _lastAddTick) return;
      if (prev != null && next.addTick <= prev.addTick) return;
      _lastAddTick = next.addTick;
      if (next.canCreate && !_busy) _openForm();
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/crm'),
        ),
        title: Text(labelPlural),
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ContactSearchField(
                  controller: _searchCtrl,
                  placeholder: AppTranslations.translate(
                    context,
                    ref,
                    'crm_search_contacts',
                  ),
                  onChanged: (v) => setState(() => _q = v.trim()),
                ),
              ),
              Expanded(
                child: contactsAsync.when(
                  loading: () => const CrmLoading(),
                  error: (e, _) => CrmErrorBox(message: e.toString()),
                  data: (all) {
                    _syncShellMeta(all, myId, perms.create);
                    final mine =
                        all.where((c) => isMineContact(c, myId)).toList();
                    final visible =
                        ui.scope == ContactScope.mine ? mine : all;
                    if (visible.isEmpty) {
                      final msg = ui.scope == ContactScope.mine
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
