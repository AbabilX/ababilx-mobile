import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../providers/chat_connections_provider.dart';
import 'people_row.dart';

class RequestsTab extends ConsumerWidget {
  const RequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatConnectionsProvider);
    final rows = [...state.requests, ...state.sent];
    if (state.loading && rows.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (rows.isEmpty) {
      return Center(
        child: Text(
          AppTranslations.translate(context, ref, 'chat_no_requests'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: ref.read(chatConnectionsProvider.notifier).refresh,
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 74),
        itemBuilder: (_, index) {
          final request = rows[index];
          return PeopleRow(
            user: request.user,
            trailing: request.direction == 'incoming'
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: AppTranslations.translate(
                          context,
                          ref,
                          'chat_reject',
                        ),
                        onPressed: () => ref
                            .read(chatConnectionsProvider.notifier)
                            .respond(request.id, accept: false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      IconButton.filled(
                        tooltip: AppTranslations.translate(
                          context,
                          ref,
                          'chat_accept',
                        ),
                        onPressed: () => ref
                            .read(chatConnectionsProvider.notifier)
                            .respond(request.id, accept: true),
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ],
                  )
                : Text(AppTranslations.translate(context, ref, 'chat_sent')),
          );
        },
      ),
    );
  }
}
