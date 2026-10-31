import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// No Spaces yet: the two ways in.
class SpacesEmptyView extends StatelessWidget {
  const SpacesEmptyView({
    super.key,
    required this.onCreate,
    required this.onJoin,
  });

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Center(
      key: const Key('spaces-empty'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedUserGroup03,
              color: c.primary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text('No spaces yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'A space is a community with its own channels. Start one, or join with an invite link.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onCreate,
                child: const Text('Create a space'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onJoin,
                child: const Text('Join with a link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
