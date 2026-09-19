import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';

import '../nav_back.dart';

/// Top bar used before the conversation metadata is known (deep link opened
/// straight from a push notification, sidebar still loading).
class ConversationPlaceholderHeader extends StatelessWidget {
  const ConversationPlaceholderHeader({super.key, this.title = 'Conversation'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: NavigationToolbar(
            leading: AppBarBackButton(
              onPressed: () => popOrGoMessages(context),
            ),
            middle: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            centerMiddle: true,
          ),
        ),
      ),
    );
  }
}

/// Shown while chat bootstrap (profile → vault → sidebar) is still running.
class ConversationLoading extends StatelessWidget {
  const ConversationLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ConversationPlaceholderHeader(),
        Expanded(
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      ],
    );
  }
}

/// Bootstrap finished but this conversation is not in the user's list — it was
/// deleted, or they lost access.
class ConversationUnavailable extends StatelessWidget {
  const ConversationUnavailable({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        const ConversationPlaceholderHeader(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 40,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Conversation unavailable',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'It may have been deleted, or you no longer have access.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
