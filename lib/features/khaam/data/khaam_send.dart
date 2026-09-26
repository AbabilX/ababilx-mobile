import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/providers/chat_provider.dart';
import 'khaam_payload.dart';

/// Posts [payload] as an ordinary message — the same send path, encryption,
/// outbox and reconciliation as text. A send that fails leaves the bubble
/// failed and retryable with the same body.
///
/// Returns false when the message did not reach the server yet.
Future<bool> sendKhaam(
  WidgetRef ref, {
  required String conversationId,
  required KhaamPayload payload,
}) async {
  try {
    final sent = await ref
        .read(chatProvider.notifier)
        .sendMessage(
          conversationId: conversationId,
          body: encodeKhaamBody(payload),
        );
    return sent != null;
  } catch (_) {
    return false;
  }
}
