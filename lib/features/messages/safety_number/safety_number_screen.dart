import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'safety_number.dart';
import 'safety_number_provider.dart';

/// Signal's "Verify safety number" screen.
///
/// The digits are the whole point: a server that substituted a key cannot make
/// two people read the same numbers to each other. Everything else here is
/// there to make that comparison happen.
class SafetyNumberScreen extends ConsumerWidget {
  const SafetyNumberScreen({
    super.key,
    required this.peerUserId,
    required this.peerName,
  });

  final String peerUserId;
  final String peerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(safetyNumberProvider(peerUserId));

    return Scaffold(
      appBar: AppBar(title: const Text('Safety number')),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Message(
            text: 'Could not work out a safety number for this conversation.',
            theme: theme,
          ),
          data: (info) => info == null
              ? _Message(
                  text:
                      '$peerName has not set up secure messages yet, so there '
                      'is nothing to compare.',
                  theme: theme,
                )
              : _Body(info: info, peerName: peerName, peerUserId: peerUserId),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.info,
    required this.peerName,
    required this.peerUserId,
  });

  final SafetyNumberInfo info;
  final String peerName;
  final String peerUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groups = safetyNumberGroups(info.digits);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        if (info.changed) ...[
          _ChangedNotice(peerName: peerName),
          const SizedBox(height: 20),
        ],
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SelectionArea(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 12,
              children: [
                for (final group in groups)
                  Text(
                    group,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Read these numbers to $peerName over a call, or compare them side '
          'by side in person. If they match, nobody is reading this '
          'conversation but the two of you.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (info.changed) ...[
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await acknowledgeSafetyNumber(
                ref,
                peerUserId,
                info.peerFingerprint,
              );
              if (context.mounted) Navigator.of(context).maybePop();
            },
            child: Text('I compared them — this is $peerName'),
          ),
        ],
      ],
    );
  }
}

class _ChangedNotice extends StatelessWidget {
  const _ChangedNotice({required this.peerName});

  final String peerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gpp_maybe, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your safety number with $peerName has changed. They may have '
              'reinstalled AbabilX or switched devices — or someone may be '
              'intercepting this conversation. Until you confirm it is them, '
              'your phone will not give them the keys to older messages.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
