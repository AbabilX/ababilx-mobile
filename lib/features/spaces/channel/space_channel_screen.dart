import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_toast.dart';
import '../data/space_models.dart';
import '../providers/space_channel_provider.dart';
import '../providers/spaces_providers.dart';
import '../ui/spaces_states.dart';
import 'space_composer.dart';
import 'space_message_row.dart';

/// One channel: timeline newest at the bottom, composer under it. Saved
/// messages show when offline; a message that fails to send stays with
/// "Not sent · Tap to retry", so nothing typed is lost.
class SpaceChannelScreen extends ConsumerWidget {
  const SpaceChannelScreen({
    super.key,
    required this.spaceId,
    required this.channelId,
  });

  final String spaceId;
  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final channel = ref
        .watch(spaceTreeProvider(spaceId))
        .data
        ?.channel(channelId);
    final name = channel?.name ?? 'channel';
    final key = (spaceId: spaceId, channelId: channelId);
    final load = ref.watch(spaceChannelProvider(key));
    final notifier = ref.read(spaceChannelProvider(key).notifier);
    final messages = load.data;

    final Widget body;
    if (messages == null && load.failure != null) {
      body = SpacesErrorView(
        failure: load.failure!,
        onRetry: notifier.refresh,
        busy: load.loading,
      );
    } else if (messages == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (messages.isEmpty) {
      body = Center(
        key: const Key('channel-empty'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'This is the start of #$name',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: c.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: messages.length,
          itemBuilder: (_, i) => SpaceMessageRow(
            key: ValueKey(
              messages[i].clientId.isEmpty
                  ? messages[i].id
                  : messages[i].clientId,
            ),
            message: messages[i],
            onRetry: () => notifier.retry(messages[i].clientId),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(
                  icon: channel?.kind == SpaceChannelKind.announcement
                      ? HugeIcons.strokeRoundedMegaphone01
                      : HugeIcons.strokeRoundedHashtag,
                  color: c.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (channel?.isPrivate ?? false) ...[
                  const SizedBox(width: 6),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedSquareLock02,
                    color: c.onSurfaceVariant,
                    size: 16,
                  ),
                ],
              ],
            ),
            Text(
              'Not end-to-end encrypted',
              style: theme.textTheme.labelSmall?.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (messages != null && load.failure != null)
            SpacesBanner(
              failure: load.failure!,
              onRetry: notifier.refresh,
              busy: load.loading,
            ),
          Expanded(child: body),
          SpaceComposer(
            hint: 'Message #$name',
            onSend: (text) {
              if (text.trim().length > spaceMessageMaxChars) {
                showAppToast(context, 'Message is too long', isError: true);
                return false;
              }
              notifier.send(text);
              return text.trim().isNotEmpty;
            },
          ),
        ],
      ),
    );
  }
}
