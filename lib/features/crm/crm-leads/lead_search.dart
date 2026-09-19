import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/crm_contacts_provider.dart';
import '../providers/crm_leads_provider.dart';
import '../providers/crm_leads_ui_provider.dart';
import '../shared/crm_money.dart';
import 'lead_row.dart';

/// Leads-page only — never chat/wall/contact search.
void openLeadSearch(BuildContext context, WidgetRef ref) {
  final initial = ref.read(crmLeadsUiProvider).searchQuery;
  final hint = AppTranslations.translate(context, ref, 'crm_search_leads');
  showSearch<void>(
    context: context,
    query: initial,
    delegate: LeadSearchDelegate(ref, searchFieldLabel: hint),
  );
}

class LeadSearchDelegate extends SearchDelegate<void> {
  LeadSearchDelegate(this.ref, {required String searchFieldLabel})
    : super(searchFieldLabel: searchFieldLabel);

  final WidgetRef ref;

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        icon: const ChatIcon(HugeIcons.strokeRoundedCancel01),
        onPressed: () {
          query = '';
          ref.read(crmLeadsUiProvider.notifier).setSearchQuery('');
          showSuggestions(context);
        },
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const AppBarBackIcon(),
    onPressed: () {
      ref.read(crmLeadsUiProvider.notifier).setSearchQuery(query.trim());
      close(context, null);
    },
  );

  @override
  void showResults(BuildContext context) {
    ref.read(crmLeadsUiProvider.notifier).setSearchQuery(query.trim());
    super.showResults(context);
  }

  @override
  Widget buildResults(BuildContext context) => _body(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    ref.read(crmLeadsUiProvider.notifier).setSearchQuery(query.trim());
    return _body(context);
  }

  Widget _body(BuildContext context) {
    final q = query.trim();
    final async = ref.watch(crmLeadsProvider(q));
    final ui = ref.watch(crmLeadsUiProvider);
    final myId = ref.watch(profileProvider).valueOrNull?.id ?? '';
    final currency =
        ref.watch(crmConfigProvider).valueOrNull?.settings.currency ?? 'BDT';
    final hint = AppTranslations.translate(context, ref, 'crm_search_leads');
    final emptyMsg = AppTranslations.translate(
      context,
      ref,
      'crm_search_leads_empty',
    );

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      error: (e, _) => Center(child: Text('$e')),
      data: (all) {
        final mine = all.where((l) => isMineLead(l, myId)).toList();
        final visible = ui.scope == LeadScope.mine ? mine : all;
        if (q.isEmpty) {
          return Center(
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        if (visible.isEmpty) {
          return Center(child: Text(emptyMsg));
        }
        return ListView.separated(
          itemCount: visible.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final l = visible[i];
            return LeadRow(
              lead: l,
              currency: currency,
              config: ref.watch(crmConfigProvider).valueOrNull,
              canUpdate: false,
              canDelete: false,
              onTap: () {
                ref
                    .read(crmLeadsUiProvider.notifier)
                    .setSearchQuery(query.trim());
                close(context, null);
                context.push('/crm/leads/${l.id}');
              },
              onEdit: () {},
              onDelete: () {},
            );
          },
        );
      },
    );
  }
}
