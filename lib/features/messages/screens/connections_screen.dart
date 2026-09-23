import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../../core/network/first_load_timeout.dart';
import '../../policy/widgets/policy_gate_overlay.dart';
import '../chat-people/connection_row.dart';
import '../chat-people/connections_filter.dart';
import '../chat-people/remove_connection_dialog.dart';
import '../data/models/chat_connection.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';
import 'blocked_connections_screen.dart';

class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> {
  Timer? _stallWatchdog;
  bool _stalled = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(chatConnectionsProvider);
      if (current.connections.isNotEmpty) return;
      unawaited(
        ref
            .read(chatConnectionsProvider.notifier)
            .refresh(force: current.loading),
      );
    });
  }

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

  Future<void> _openChat(String userId) async {
    final dm = await ref.read(chatProvider.notifier).startDm(userId);
    if (!mounted) return;
    context.push('/messages/${dm.id}');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatConnectionsProvider);
    _armWatchdog(state.loading);

    final filtered = filterConnections(state.connections, _searchQuery);
    final searching = _searchQuery.trim().isNotEmpty;

    String t(String key) => AppTranslations.translate(context, ref, key);

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          appBar: AppBar(
            leading: const AppBarBackButton(),
            title: Text(t('chat_connections')),
            actions: [
              IconButton(
                tooltip: t('chat_blocked_people'),
                icon: const Icon(Icons.block_rounded),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BlockedConnectionsScreen(),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (state.loading) const LinearProgressIndicator(minHeight: 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SearchBar(
                  hintText: t('chat_search_connections'),
                  leading: const Icon(Icons.search_rounded),
                  onChanged: (value) => setState(() => _searchQuery = value),
                  trailing: _searchQuery.isEmpty
                      ? null
                      : [
                          IconButton(
                            onPressed: () => setState(() => _searchQuery = ''),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                ),
              ),
              if (state.connections.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      searching
                          ? t(
                              'chat_connections_match_count',
                            ).replaceAll('{n}', '${filtered.length}')
                          : t(
                              'chat_connections_count',
                            ).replaceAll('{n}', '${state.connections.length}'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref
                      .read(chatConnectionsProvider.notifier)
                      .refresh(force: true),
                  child: _buildBody(
                    context,
                    ref: ref,
                    state: state,
                    filtered: filtered,
                    searching: searching,
                    stalled: _stalled,
                    t: t,
                  ),
                ),
              ),
            ],
          ),
        ),
        const PolicyGateOverlay(),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required WidgetRef ref,
    required ChatConnectionsState state,
    required List<ChatConnection> filtered,
    required bool searching,
    required bool stalled,
    required String Function(String) t,
  }) {
    if (state.connections.isEmpty) {
      return _EmptyConnections(
        state: state,
        stalled: stalled,
        t: t,
        onRetry: () =>
            ref.read(chatConnectionsProvider.notifier).refresh(force: true),
      );
    }
    if (searching && filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 72),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                t('chat_no_connections_match'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: filtered.length,
      itemBuilder: (_, index) {
        final connection = filtered[index];
        final name = connection.user.name.trim().isEmpty
            ? t('chat_someone')
            : connection.user.name.trim();
        return ConnectionRow(
          connection: connection,
          messageLabel: t('chat_message'),
          removeLabel: t('chat_remove'),
          blockLabel: t('chat_block'),
          sharedWorkspaceLabel: t('chat_shared_workspace'),
          onOpenChat: () => unawaited(_openChat(connection.user.userId)),
          onRemove: () async {
            final ok = await confirmRemoveConnection(context, ref, name: name);
            if (!ok || !mounted) return;
            await ref
                .read(chatConnectionsProvider.notifier)
                .remove(connection.user.userId);
          },
          onBlock: () async {
            final ok = await confirmBlockConnection(context, ref, name: name);
            if (!ok || !mounted) return;
            await ref
                .read(chatConnectionsProvider.notifier)
                .block(connection.user.userId);
          },
        );
      },
    );
  }
}

class _EmptyConnections extends StatelessWidget {
  const _EmptyConnections({
    required this.state,
    required this.stalled,
    required this.t,
    required this.onRetry,
  });

  final ChatConnectionsState state;
  final bool stalled;
  final String Function(String) t;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final policyBlocked = state.error == chatConnectionsPolicyGateError;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        if (state.error.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              policyBlocked
                  ? t('chat_connections_policy_required')
                  : state.error,
              textAlign: TextAlign.center,
            ),
          ),
          if (!policyBlocked)
            Center(
              child: TextButton(
                onPressed: onRetry,
                child: Text(t('chat_tap_to_retry')),
              ),
            ),
        ] else if (state.loading || stalled)
          Center(child: Text(t('chat_connections_loading')))
        else
          Center(child: Text(t('chat_no_connections'))),
      ],
    );
  }
}
