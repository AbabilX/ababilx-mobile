import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../calls/data/models/ice_server.dart';

/// `GET /api/messaging/history-live/:id` — what the phone needs to open the
/// channel: fresh ICE servers (TURN credentials are short-lived) and the
/// window the server states.
class LiveLinkInfo {
  const LiveLinkInfo({required this.iceServers, required this.windowDays});

  final List<IceServer> iceServers;
  final int windowDays;
}

class LiveApi {
  const LiveApi(this._client);

  final ApiClient _client;

  Future<LiveLinkInfo> link(String id) async {
    final res = await _client.get('${ApiConstants.historyLive}/$id');
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return LiveLinkInfo(
      iceServers: [
        for (final s in (data['ice_servers'] as List? ?? const []))
          IceServer.fromJson(Map<String, dynamic>.from(s as Map)),
      ],
      windowDays: (data['window_days'] as num?)?.toInt() ?? 90,
    );
  }
}
