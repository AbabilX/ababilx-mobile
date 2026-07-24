import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/team_models.dart';

class TeamRepository {
  const TeamRepository(this._client);
  final ApiClient _client;

  Future<TeamDetail?> getMyTeam() async {
    final res = await _client.get(ApiConstants.teamsMe);
    final data = unwrapApiData<Map<String, dynamic>?>(res);
    if (data == null) return null;
    final detail = TeamDetail.fromJson(data);
    return detail.hasTeam ? detail : null;
  }
}

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => TeamRepository(ref.watch(apiClientProvider)),
);
