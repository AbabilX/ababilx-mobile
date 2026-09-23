import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/friendly_error.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/chat_repository.dart';
import '../providers/blocked_connections_provider.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';

class BlockedConnectionsScreen extends ConsumerStatefulWidget {
  const BlockedConnectionsScreen({super.key});

  @override
  ConsumerState<BlockedConnectionsScreen> createState() =>
      _BlockedConnectionsScreenState();
}

class _BlockedConnectionsScreenState
    extends ConsumerState<BlockedConnectionsScreen> {
  final _busy = <String>{};

  String _tr(String key) => AppTranslations.translate(context, ref, key);

  Future<void> _unblock(String userId) async {
    if (!_busy.add(userId)) return;
    setState(() {});
    try {
      // DELETE lifts only our own block; it does not restore acceptance.
      await ref.read(chatRepositoryProvider).removeConnection(userId);
      if (!mounted) return;
      ref.invalidate(blockedConnectionsProvider);
      ref.read(chatConnectionsProvider.notifier).refresh(force: true).ignore();
      ref.read(chatProvider.notifier).fetchSidebarSilent().ignore();
      showAppToast(context, _tr('chat_unblocked'));
    } catch (error) {
      if (mounted) {
        showAppToast(context, friendlyErrorMessage(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = ref.watch(blockedConnectionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_tr('chat_blocked_people'))),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(friendlyErrorMessage(error)),
              TextButton(
                onPressed: () => ref.invalidate(blockedConnectionsProvider),
                child: Text(_tr('chat_tap_to_retry')),
              ),
            ],
          ),
        ),
        data: (people) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(blockedConnectionsProvider);
            // The provider renders a retryable error if refreshing fails.
            await ref
                .read(blockedConnectionsProvider.future)
                .then<void>(
                  (_) {},
                  onError: (Object error, StackTrace stack) {},
                );
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_tr('chat_unblock_hint')),
              ),
              if (people.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(_tr('chat_no_blocked_people'))),
                ),
              for (final connection in people) ...[
                ListTile(
                  title: Text(connection.user.name),
                  subtitle: connection.user.username.isEmpty
                      ? null
                      : Text('@${connection.user.username}'),
                  trailing: TextButton(
                    onPressed: _busy.contains(connection.user.userId)
                        ? null
                        : () => _unblock(connection.user.userId),
                    child: Text(_tr('chat_unblock')),
                  ),
                ),
                const Divider(height: 1),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
