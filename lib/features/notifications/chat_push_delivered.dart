import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import 'chat_push_notification.dart';

typedef DeliveredReceiptPoster =
    Future<void> Function(SecureStorage storage, Map<String, dynamic> body);

final Set<String> _ackedMessageIds = <String>{};

/// Tells the sender their message reached this phone — the second tick —
/// from the push that carried it.
///
/// The tick used to go only when a message arrived over the realtime socket or
/// a page load, and that socket now closes two minutes after the app leaves
/// the screen (`WsBackgroundRelease`). Without this, a message to a phone in a
/// pocket stayed on one tick until its owner opened the app. WhatsApp sends
/// "delivered" when the push lands; this is the same moment. Never "read".
///
/// Raw secure storage, not Riverpod: the FCM background isolate has no
/// provider scope. Uses the messaging device this phone already registered and
/// never registers one (that mints keys); the server ignores an unknown or
/// revoked device and a repeat receipt. Best effort: a failure leaves the tick
/// to the next time the app opens, which is how it always worked.
Future<void> postChatPushDelivered(
  Map<String, dynamic> data, {
  SecureStorage storage = const SecureStorage(FlutterSecureStorage()),
  DeliveredReceiptPoster post = _postReceipt,
}) async {
  final messageId = chatPushMessageId(data);
  if (messageId == null || _ackedMessageIds.contains(messageId)) return;
  try {
    final token = await storage.readJwt();
    if (token == null || token.isEmpty) return;
    final deviceId = messagingDeviceIdFrom(
      await storage.readMessagingDeviceIdentity(),
    );
    if (deviceId == null) return;
    await post(storage, deliveredReceiptBody(deviceId, messageId));
    if (_ackedMessageIds.length >= 512) _ackedMessageIds.clear();
    _ackedMessageIds.add(messageId);
  } catch (_) {
    // Best effort by design; the next open acknowledges it.
  }
}

Future<void> _postReceipt(SecureStorage storage, Map<String, dynamic> body) =>
    ApiClient(storage).post(ApiConstants.messagingReceipts, data: body);

/// The message a chat push is about, or null for anything else.
String? chatPushMessageId(Map<String, dynamic> data) {
  if (!isChatPush(data)) return null;
  final id = data['message_id']?.toString().trim() ?? '';
  return id.isEmpty ? null : id;
}

/// The id of this phone's registered messaging device, read out of the stored
/// identity (`LocalChatDeviceIdentity.toJson`). Null when there is none yet.
String? messagingDeviceIdFrom(String? storedIdentity) {
  if (storedIdentity == null || storedIdentity.isEmpty) return null;
  try {
    final decoded = jsonDecode(storedIdentity);
    if (decoded is! Map) return null;
    final id = decoded['device_id']?.toString().trim() ?? '';
    return id.isEmpty ? null : id;
  } catch (_) {
    return null;
  }
}

/// `POST /api/messaging/receipts`, the same body the socket path sends.
Map<String, dynamic> deliveredReceiptBody(String deviceId, String messageId) => {
  'device_id': deviceId,
  'status': 'delivered',
  'message_ids': [messageId],
};
