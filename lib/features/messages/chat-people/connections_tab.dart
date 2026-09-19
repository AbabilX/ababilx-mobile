import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/first_load_timeout.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';
import 'people_row.dart';
import 'remove_connection_dialog.dart';

/// Never a blocking full-screen spinner. Shows a thin progress bar, then
/// either the list, empty state, or an error with retry.
class ConnectionsTab extends ConsumerStatefulWidget {
  const ConnectionsTab({super.key});

  @override
  ConsumerState<ConnectionsTab> createState() => _ConnectionsTabState();
}

class _ConnectionsTabState extends ConsumerState<ConnectionsTab> {
  Timer? _stallWatchdog;
  bool _stalled = false;

  @override
  void dispose() {
    _stallWatchdog?.cancel();
    super.dispose();
  }

  void _armWatchdog(bool loading) {
    _stallWatchdog?.cancel();
    _stallWatchdog = null;
    if (!loading) {
      if (_stalled) setState(() => _stalled = false);
      return;
    }
    _stallWatchdog = Timer(
      firstLoadNetworkTimeout + const Duration(seconds: 2),
      () {
        if (!mounted) return;
        final state = ref.read(chatConnectionsProvider);
        if (!state.loading || state.connections.isNotEmpty) return;
        setState(() => _stalled = true);
        if (kDebugMode) {
          debugPrint('[connections] load stalled — forcing refresh');
        }
        unawaited(
          ref.read(chatConnectionsProvider.notifier).refresh(force: true),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatConnectionsProvider);
    _armWatchdog(state.loading);

    return Column(
      children: [
        if (state.loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(chatConnectionsProvider.notifier).refresh(force: true),
            child: state.connections.isEmpty
                ? _EmptyConnections(state: state, stalled: _stalled)
                : _ConnectionList(state: state),
          ),
        ),
      ],
    );
  }
}

class _EmptyConnections extends ConsumerWidget {
  const _EmptyConnections({required this.state, required this.stalled});

  final ChatConnectionsState state;
  final bool stalled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policyBlocked =
        state.error == chatConnectionsPolicyGateError;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        if (state.error.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              policyBlocked
                  ? AppTranslations.translate(
                      context,
                      ref,
                      'chat_connections_policy_required',
                    )
                  : state.error,
              textAlign: TextAlign.center,
            ),
          ),
          if (!policyBlocked)
            TextButton(
              onPressed: () => ref
                  .read(chatConnectionsProvider.notifier)
                  .refresh(force: true),
              child: Text(
                AppTranslations.translate(context, ref, 'chat_tap_to_retry'),
              ),
            ),
        ] else if (state.loading || stalled)
          Center(
            child: Text(
              AppTranslations.translate(
                context,
                ref,
                'chat_connections_loading',
              ),
            ),
          )
        else
          Center(
            child: Text(
              AppTranslations.translate(context, ref, 'chat_no_connections'),
            ),
          ),
      ],
    );
  }
}

class _ConnectionList extends ConsumerWidget {
  const _ConnectionList({required this.state});

  final ChatConnectionsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
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
                    ? AppTranslations.translate(context, ref, 'chat_someone')
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
    );
  }
}
