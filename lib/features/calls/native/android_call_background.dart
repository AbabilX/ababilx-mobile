import 'dart:ui';

import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

/// Persists native decline/end actions when Android has no foreground Flutter
/// UI. Accept is recovered by [VoiceCallNotifier] in the main isolate.
@pragma('vm:entry-point')
Future<void> androidCallkitBackgroundHandler(CallEvent event) async {
  DartPluginRegistrant.ensureInitialized();

  final actionData = switch (event) {
    CallEventActionCallDecline(:final callKitParams) => (
      callKitParams.id,
      'decline',
    ),
    CallEventActionCallEnded(:final callKitParams) => (
      callKitParams.id,
      callKitParams.isAccepted ? 'end' : 'decline',
    ),
    _ => null,
  };
  if (actionData == null) return;
  final (callId, action) = actionData;
  if (callId.isEmpty) return;

  try {
    final storage = SecureStorage(const FlutterSecureStorage());
    final token = await storage.readJwt();
    if (token == null || token.isEmpty) return;
    final client = ApiClient(storage);
    await client.post(
      ApiConstants.chatVoiceCallActions(callId),
      data: {'action': action},
    );
  } catch (_) {
    // The server's ring sweeper remains the fallback for an offline decline.
  }
}
