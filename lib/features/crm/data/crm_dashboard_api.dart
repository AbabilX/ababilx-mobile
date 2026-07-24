import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/crm_dashboard.dart';

class CrmDashboardApi {
  const CrmDashboardApi(this._client);
  final ApiClient _client;

  Future<CrmDashboard> get() async {
    final res = await _client.get(ApiConstants.crmDashboard);
    return CrmDashboard.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }
}
