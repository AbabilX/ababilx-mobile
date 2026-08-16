import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import 'group_call_api.dart';
import 'models/group_call.dart';
import 'models/group_call_session.dart';

class GroupCallRepository {
  const GroupCallRepository(this._api);

  final GroupCallApi _api;

  Future<GroupCall?> active(String conversationId) =>
      _api.active(conversationId);

  Future<GroupCallSession> join(String conversationId) =>
      _api.join(conversationId);

  Future<GroupCall?> leave(String callId) => _api.leave(callId);

  Future<GroupCall?> claimScreenShare(String callId) =>
      _api.screenShare(callId, 'claim');

  Future<GroupCall?> releaseScreenShare(String callId) =>
      _api.screenShare(callId, 'release');
}

final groupCallRepositoryProvider = Provider<GroupCallRepository>((ref) {
  return GroupCallRepository(GroupCallApi(ref.watch(apiClientProvider)));
});
