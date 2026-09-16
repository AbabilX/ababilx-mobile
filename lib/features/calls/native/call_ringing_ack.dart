import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

final Set<String> _ackedCallIds = <String>{};

/// Tells the server this device is ringing for [callId], so the caller reads
/// "Ringing…" instead of "Calling…".
///
/// Built on raw secure storage rather than Riverpod because the FCM background
/// isolate — the path a killed app rings through — has no provider scope.
/// Once per call per isolate; the server also stamps only the first report, so
/// several devices ringing tell the caller exactly once. A failure is silent:
/// the caller simply keeps saying "Calling…".
Future<void> postVoiceCallRingingAck(String callId) async {
  if (callId.isEmpty || !_ackedCallIds.add(callId)) return;
  try {
    final storage = SecureStorage(const FlutterSecureStorage());
    final token = await storage.readJwt();
    if (token == null || token.isEmpty) return;
    await ApiClient(storage).post(
      ApiConstants.chatVoiceCallActions(callId),
      data: {'action': 'ringing'},
    );
  } catch (_) {
    // Best effort by design.
  }
}
