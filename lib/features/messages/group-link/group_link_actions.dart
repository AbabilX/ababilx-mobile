import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/widgets/app_toast.dart';

/// What an admin can do with a link that exists: hand it out, pause it, or
/// remove it.
///
/// Pause and remove are different promises, so the sheet says which is which:
/// a paused link keeps its name and comes back; a removed one is gone, and
/// anyone may take the name.
class GroupLinkActions extends StatelessWidget {
  const GroupLinkActions({
    super.key,
    required this.link,
    required this.paused,
    required this.busy,
    required this.onPause,
    required this.onRemove,
  });

  final String link;
  final bool paused;
  final bool busy;
  final ValueChanged<bool> onPause;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        if (!paused)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (context.mounted) showAppToast(context, 'Link copied');
                  },
                  child: const Text('Copy link'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(text: 'Join my group on AbabilX: $link'),
                  ),
                  child: const Text('Share link'),
                ),
              ),
            ],
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pause link'),
          subtitle: Text(
            paused
                ? 'Nobody can join with it. The name stays yours.'
                : 'Stop new people joining, without losing the name.',
          ),
          value: paused,
          onChanged: busy ? null : onPause,
        ),
        TextButton(
          onPressed: busy ? null : onRemove,
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: const Text('Remove link'),
        ),
        Text(
          'Removing frees the name for any group. Members stay.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
