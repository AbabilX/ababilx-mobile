import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session_state.dart';
import '../providers/local_share_providers.dart';
import 'transfer_progress_tile.dart';

/// Outgoing session card shown in the Send tab's transfer list.
class SendSessionCard extends ConsumerWidget {
  const SendSessionCard({super.key, required this.session});

  final ShareSessionState session;

  bool get _active =>
      session.status == TransferSessionStatus.sending ||
      session.status == TransferSessionStatus.waitingForRecipient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'To ${session.targetDevice.alias}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (_active)
                TextButton(
                  onPressed: () => ref
                      .read(localShareSessionsProvider.notifier)
                      .cancelSession(session.sessionId),
                  child: const Text('Cancel'),
                ),
            ],
          ),
          for (final f in session.files.values)
            TransferProgressTile(progress: f),
        ],
      ),
    );
  }
}
