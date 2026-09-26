import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/providers/chat_provider.dart';
import 'jpack_payload.dart';

/// Posts [payload] as an ordinary message — the same send path, encryption,
/// outbox and reconciliation as text. A send that fails leaves the bubble
/// failed and retryable with the same body.
///
/// Returns false when the message did not reach the server yet.
Future<bool> sendJPack(
  WidgetRef ref, {
  required String conversationId,
  required JPackPayload payload,
}) async {
  try {
    final sent = await ref
        .read(chatProvider.notifier)
        .sendMessage(
          conversationId: conversationId,
          body: encodeJPackBody(payload),
        );
    return sent != null;
  } catch (_) {
    return false;
  }
}
