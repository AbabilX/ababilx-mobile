import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';
import '../data/models/chat_connection.dart';
import 'people_row.dart';

class FindPeopleTab extends ConsumerStatefulWidget {
  const FindPeopleTab({super.key});

  @override
  ConsumerState<FindPeopleTab> createState() => _FindPeopleTabState();
}

class _FindPeopleTabState extends ConsumerState<FindPeopleTab> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(chatConnectionsProvider.notifier).search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatConnectionsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _search,
            autocorrect: false,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: AppTranslations.translate(
                context,
                ref,
                'chat_search_people',
              ),
              // Email and phone are exact matches and phone needs the country
              // code, so the field says so rather than letting people guess.
              helperText: '@username, email, or +8801712345678',
              helperMaxLines: 2,
            ),
          ),
        ),
        if (state.searching) const LinearProgressIndicator(minHeight: 2),
        if (state.error.isNotEmpty && !state.searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              state.error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: state.searchResults.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 74),
            itemBuilder: (_, index) {
              final user = state.searchResults[index];
              return PeopleRow(
                user: user,
                trailing: _action(context, ref, user),
              );
            },
          ),
        ),
      ],
    );
  }

  /// One action for everyone. There is no "connect first" state left to
  /// render: the server allows the DM, and the person on the other end
  /// answers the message request inside the thread.
  Widget _action(BuildContext context, WidgetRef ref, ChatUserSummary user) {
    return TextButton(
      onPressed: () async {
        final dm = await ref.read(chatProvider.notifier).startDm(user.userId);
        if (context.mounted) context.push('/messages/${dm.id}');
      },
      child: Text(AppTranslations.translate(context, ref, 'chat_message')),
    );
  }
}
