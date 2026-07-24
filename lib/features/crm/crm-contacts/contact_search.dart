import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/crm_contacts_provider.dart';
import '../providers/crm_contacts_ui_provider.dart';
import '../shared/crm_money.dart';
import 'contact_row.dart';

/// Contacts-page only — never chat/wall search.
void openContactSearch(BuildContext context, WidgetRef ref) {
  final initial = ref.read(crmContactsUiProvider).searchQuery;
  final hint = AppTranslations.translate(context, ref, 'crm_search_contacts');
  showSearch<void>(
    context: context,
    query: initial,
    delegate: ContactSearchDelegate(ref, searchFieldLabel: hint),
  );
}

/// Searches `GET /api/teams/crm/contacts?q=` only (scoped My/All).
class ContactSearchDelegate extends SearchDelegate<void> {
  ContactSearchDelegate(
    this.ref, {
    required String searchFieldLabel,
  }) : super(searchFieldLabel: searchFieldLabel);

  final WidgetRef ref;

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const ChatIcon(HugeIcons.strokeRoundedCancel01),
            onPressed: () {
              query = '';
              ref.read(crmContactsUiProvider.notifier).setSearchQuery('');
              showSuggestions(context);
            },
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const ChatIcon(HugeIcons.strokeRoundedArrowLeft01),
        onPressed: () {
          ref.read(crmContactsUiProvider.notifier).setSearchQuery(query.trim());
          close(context, null);
        },
      );

  @override
  void showResults(BuildContext context) {
    ref.read(crmContactsUiProvider.notifier).setSearchQuery(query.trim());
    super.showResults(context);
  }

  @override
  Widget buildResults(BuildContext context) => _body(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    ref.read(crmContactsUiProvider.notifier).setSearchQuery(query.trim());
    return _body(context);
  }

  Widget _body(BuildContext context) {
    final q = query.trim();
    // CRM contacts API only — not chat/wall providers.
    final async = ref.watch(crmContactsProvider(q));
    final ui = ref.watch(crmContactsUiProvider);
    final myId = ref.watch(profileProvider).valueOrNull?.id ?? '';
    final currency =
        ref.watch(crmConfigProvider).valueOrNull?.settings.currency ?? 'BDT';
    final hint = AppTranslations.translate(
      context,
      ref,
      'crm_search_contacts',
    );
    final emptyMsg = AppTranslations.translate(
      context,
      ref,
      'crm_search_empty',
    );

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
      error: (e, _) => Center(child: Text('$e')),
      data: (all) {
        final mine = all.where((c) => isMineContact(c, myId)).toList();
        final visible = ui.scope == ContactScope.mine ? mine : all;
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
            final c = visible[i];
            return ContactRow(
              contact: c,
              currency: currency,
              canUpdate: false,
              canDelete: false,
              onTap: () {
                ref
                    .read(crmContactsUiProvider.notifier)
                    .setSearchQuery(query.trim());
                close(context, null);
                context.push('/crm/contacts/${c.id}');
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
