import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/crm_models.dart';

class CrmConfigApi {
  const CrmConfigApi(this._client);
  final ApiClient _client;

  Future<CrmConfig> get() async {
    final res = await _client.get(ApiConstants.crmConfig);
    return CrmConfig.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }
}
