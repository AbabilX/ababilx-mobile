import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/crm_search_hit.dart';
import 'models/workspace_search_hit.dart';

String extractApiError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    if (e.message != null && e.message!.isNotEmpty) return e.message!;
  }
  return e.toString();
}

class WorkspaceSearchApi {
  const WorkspaceSearchApi(this._client);
  final ApiClient _client;

  Future<List<WorkspaceSearchHit>> search(String q, {int limit = 15}) async {
    final res = await _client.get(
      ApiConstants.aiSearchMessages,
      queryParameters: {'q': q, 'limit': limit},
    );
    final raw = unwrapApiData<dynamic>(res);
    if (raw is! List) return const [];
    return raw
        .map(
          (e) =>
              WorkspaceSearchHit.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }
}

class CrmDeepSearchApi {
  const CrmDeepSearchApi(this._client);
  final ApiClient _client;

  Future<List<CrmSearchHit>> search(String q, {int limit = 20}) async {
    final res = await _client.get(
      ApiConstants.crmSearch,
      queryParameters: {'q': q, 'limit': limit},
    );
    final raw = unwrapApiData<dynamic>(res);
    if (raw is! List) return const [];
    return raw
        .map((e) => CrmSearchHit.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
