import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'models/voice_call_session.dart';
import 'voice_call_api.dart';
import '../../profile/providers/profile_provider.dart';

class VoiceCallRepository {
  const VoiceCallRepository(this._api);

  final VoiceCallApi _api;

  Future<VoiceCallSession> start(String conversationId) =>
      _api.start(conversationId);

  Future<VoiceCallSession> get(String callId) => _api.get(callId);

  Future<VoiceCallSession> action(
    String callId,
    String action, {
    String? reason,
  }) => _api.action(callId, action, reason: reason);
}

final voiceCallRepositoryProvider = Provider<VoiceCallRepository>((ref) {
  final independent =
      ref.watch(profileProvider).valueOrNull?.independentChat ?? false;
  return VoiceCallRepository(
    VoiceCallApi(ref.watch(apiClientProvider), independent: independent),
  );
});
