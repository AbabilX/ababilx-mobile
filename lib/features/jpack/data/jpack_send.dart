import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/providers/chat_provider.dart';
import '../providers/jpack_providers.dart';
import 'jpack_payload.dart';

/// Pays for [payload] from the wallet, then posts it as an ordinary message —
/// the same send path, encryption, outbox and reconciliation as text.
///
/// The debit is keyed on the JPack id, so a second call for the same JPack
/// never charges twice. A send that fails leaves the bubble failed and
/// retryable with the same body; the money stays with it rather than being
/// refunded, or a retry would deliver a JPack nobody paid for.
///
/// Returns false when the message did not reach the server yet. Throws
/// `InsufficientBalance` before anything is sent.
Future<bool> sendJPack(
  WidgetRef ref, {
  required String conversationId,
  required JPackPayload payload,
}) async {
  await ref
      .read(walletBalanceProvider.notifier)
      .debit(payload.amount, ref: payload.id);
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
