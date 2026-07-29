import 'dart:ui';

import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

const _acceptGracePrefix = 'voice_call_accept_grace_';

/// Persists native decline/end actions when Android has no foreground Flutter
/// UI. Accept is recovered by [VoiceCallNotifier] in the main isolate.
///
/// After Accept, CallKit may emit a local [ACTION_CALL_ENDED] while dismissing
/// the incoming UI. That must not POST `end` and kill the WebRTC session.
@pragma('vm:entry-point')
Future<void> androidCallkitBackgroundHandler(CallEvent event) async {
  DartPluginRegistrant.ensureInitialized();

  final raw = const FlutterSecureStorage();

  switch (event) {
    case CallEventActionCallAccept(:final callKitParams):
      final id = callKitParams.id;
      if (id.isEmpty) return;
      // Grace window so a follow-up local ENDED after Accept is ignored.
      await raw.write(
        key: '$_acceptGracePrefix$id',
        value: DateTime.now().toUtc().toIso8601String(),
      );
      return;
    case CallEventActionCallDecline(:final callKitParams):
      await _postAction(raw, callKitParams.id, 'decline');
    case CallEventActionCallEnded(:final callKitParams):
      final id = callKitParams.id;
      if (id.isEmpty) return;
      if (callKitParams.isAccepted) {
        final marked = await raw.read(key: '$_acceptGracePrefix$id');
        await raw.delete(key: '$_acceptGracePrefix$id');
        if (marked != null && marked.isNotEmpty) {
          final at = DateTime.tryParse(marked)?.toLocal();
          if (at != null &&
              DateTime.now().difference(at) < const Duration(seconds: 3)) {
            // Local CallKit dismiss right after Accept — not a real hang-up.
            return;
          }
        }
        await _postAction(raw, id, 'end');
      } else {
        await _postAction(raw, id, 'decline');
      }
    default:
      return;
  }
}

Future<void> _postAction(
  FlutterSecureStorage raw,
  String callId,
  String action,
) async {
  if (callId.isEmpty) return;
  try {
    final storage = SecureStorage(raw);
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
