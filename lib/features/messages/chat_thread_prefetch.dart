import 'data/models/chat_models.dart';

/// Roots whose last-reply preview is still missing on the main timeline.
///
/// [ChatState.threadRepliesByRoot] is only filled when a thread is opened or
/// prefetched. A blank gray line until then is not a styling bug — there is
/// nothing to show. Skip a root once we already hold as many replies as
/// [ChatMessage.threadCount].
List<ChatMessage> threadRootsNeedingPreview(
  Iterable<ChatMessage> messages,
  Map<String, List<ChatMessage>> repliesByRoot,
) {
  return [
    for (final message in messages)
      if (message.threadCount > 0 &&
          (repliesByRoot[message.id]?.length ?? 0) < message.threadCount)
        message,
  ];
}
