import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/chat-timeline/message_row_content.dart';
import '../../messages/chat_utils.dart';
import '../../messages/data/models/chat_models.dart';

/// The chat timeline's own rows, newest window only, pinned to the bottom
/// the way an opened chat sits. Same bubble, cluster, name and avatar.
class CatchUpBubbles extends ConsumerWidget {
  const CatchUpBubbles({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.isGroup,
  });

  final List<ChatMessage> messages;
  final String currentUserId;
  final bool isGroup;

  static const _pulse = AlwaysStoppedAnimation<double>(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var i = 0; i < messages.length; i++)
                  MessageRowContent(
                    message: messages[i],
                    pulse: _pulse,
                    isSending: messages[i].isPending &&
                        messages[i].sendStatus != MessageSendStatus.failed,
                    isFailed: messages[i].sendStatus == MessageSendStatus.failed,
                    isOwnMessage: messages[i].userId == currentUserId,
                    clusterPosition: chatMessageClusterPosition(
                      i > 0 ? messages[i - 1] : null,
                      messages[i],
                      i + 1 < messages.length ? messages[i + 1] : null,
                    ),
                    isGroup: isGroup,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
