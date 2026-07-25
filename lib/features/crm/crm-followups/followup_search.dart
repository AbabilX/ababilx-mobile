import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_followups_provider.dart';
import '../providers/crm_followups_ui_provider.dart';
import '../shared/followup_buckets.dart';
import 'followup_row.dart';

void openFollowupSearch(BuildContext context, WidgetRef ref) {
  final initial = ref.read(crmFollowupsUiProvider).searchQuery;
  final hint = AppTranslations.translate(context, ref, 'crm_search_followups');
  showSearch<void>(
    context: context,
    query: initial,
    delegate: FollowupSearchDelegate(ref, searchFieldLabel: hint),
  );
}

class FollowupSearchDelegate extends SearchDelegate<void> {
  FollowupSearchDelegate(this.ref, {required String searchFieldLabel})
    : super(searchFieldLabel: searchFieldLabel);

  final WidgetRef ref;

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        icon: const ChatIcon(HugeIcons.strokeRoundedCancel01),
        onPressed: () {
          query = '';
          ref.read(crmFollowupsUiProvider.notifier).setSearchQuery('');
          showSuggestions(context);
        },
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const ChatIcon(HugeIcons.strokeRoundedArrowLeft01),
    onPressed: () {
      ref.read(crmFollowupsUiProvider.notifier).setSearchQuery(query.trim());
      close(context, null);
    },
  );

  @override
  void showResults(BuildContext context) {
    ref.read(crmFollowupsUiProvider.notifier).setSearchQuery(query.trim());
    super.showResults(context);
  }

  @override
  Widget buildResults(BuildContext context) => _body(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    ref.read(crmFollowupsUiProvider.notifier).setSearchQuery(query.trim());
    return _body(context);
  }

  List<CrmFollowup> _filter(List<CrmFollowup> all, String q, String myId) {
    final ui = ref.watch(crmFollowupsUiProvider);
    final mine = all.where((f) => isMineFollowup(f, myId)).toList();
    final scoped = ui.scope == FollowupScope.mine ? mine : all;
    final bySchedule = scoped.where(
      (f) => matchesFollowupSchedule(f, ui.schedule),
    );
    if (q.isEmpty) return bySchedule.toList();
    final lower = q.toLowerCase();
    return bySchedule.where((f) {
      return (f.contactName ?? '').toLowerCase().contains(lower) ||
          (f.contactCompany ?? '').toLowerCase().contains(lower) ||
          (f.contactPhone ?? '').toLowerCase().contains(lower) ||
          (f.assigneeName ?? '').toLowerCase().contains(lower);
    }).toList();
  }

  Widget _body(BuildContext context) {
    final q = query.trim();
    final async = ref.watch(crmFollowupsProvider(''));
    final myId = ref.watch(profileProvider).valueOrNull?.id ?? '';
    final hint = AppTranslations.translate(
      context,
      ref,
      'crm_search_followups',
    );
    final emptyMsg = AppTranslations.translate(
      context,
      ref,
      'crm_search_followups_empty',
    );

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      error: (e, _) => Center(child: Text('$e')),
      data: (all) {
        final visible = _filter(all, q, myId);
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
            final f = visible[i];
            return FollowupRow(
              followup: f,
              onTap: () {
                ref
                    .read(crmFollowupsUiProvider.notifier)
                    .setSearchQuery(query.trim());
                close(context, null);
                context.push('/crm/followups/${f.id}');
              },
            );
          },
        );
      },
    );
  }
}
