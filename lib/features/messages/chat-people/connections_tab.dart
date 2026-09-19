import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';
import 'people_row.dart';
import 'remove_connection_dialog.dart';

class ConnectionsTab extends ConsumerWidget {
  const ConnectionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatConnectionsProvider);
    if (state.loading && state.connections.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (state.error.isNotEmpty && state.connections.isEmpty) {
      return Center(child: Text(state.error));
    }
    if (state.connections.isEmpty) {
      return Center(
        child: Text(
          AppTranslations.translate(context, ref, 'chat_no_connections'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: ref.read(chatConnectionsProvider.notifier).refresh,
      child: ListView.separated(
        itemCount: state.connections.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 74),
        itemBuilder: (_, index) {
          final connection = state.connections[index];
          return PeopleRow(
            user: connection.user,
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'message') {
                  final dm = await ref
                      .read(chatProvider.notifier)
                      .startDm(connection.user.userId);
                  if (context.mounted) context.push('/messages/${dm.id}');
                } else if (action == 'remove') {
                  final name = connection.user.name.trim().isEmpty
                      ? AppTranslations.translate(
                          context,
                          ref,
                          'chat_someone',
                        )
                      : connection.user.name.trim();
                  final ok = await confirmRemoveConnection(
                    context,
                    ref,
                    name: name,
                  );
                  if (!ok || !context.mounted) return;
                  await ref
                      .read(chatConnectionsProvider.notifier)
                      .remove(connection.user.userId);
                } else if (action == 'block') {
                  await ref
                      .read(chatConnectionsProvider.notifier)
                      .block(connection.user.userId);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'message',
                  child: Text(
                    AppTranslations.translate(context, ref, 'chat_message'),
                  ),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    AppTranslations.translate(context, ref, 'chat_remove'),
                  ),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Text(
                    AppTranslations.translate(context, ref, 'chat_block'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
