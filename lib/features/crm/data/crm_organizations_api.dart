import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/crm_models.dart';

class CrmOrganizationsApi {
  const CrmOrganizationsApi(this._client);
  final ApiClient _client;

  Future<List<CrmOrganization>> list({String? q}) async {
    late final dynamic res;
    try {
      res = await _client.get(
        ApiConstants.crmOrganizations,
        queryParameters: {if (q != null && q.isNotEmpty) 'q': q},
      );
    } on DioException catch (error) {
      _throwFriendly(error);
    }
    final raw = unwrapApiData<dynamic>(res);
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        CrmOrganization.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  Future<CrmOrganization> get(String id) async {
    late final dynamic res;
    try {
      res = await _client.get(ApiConstants.crmOrganization(id));
    } on DioException catch (error) {
      _throwFriendly(error);
    }
    return CrmOrganization.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<CrmOrganization> create(CrmOrganizationInput body) async {
    late final dynamic res;
    try {
      res = await _client.post(
        ApiConstants.crmOrganizations,
        data: body.toJson(),
      );
    } on DioException catch (error) {
      _throwFriendly(error);
    }
    return CrmOrganization.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<CrmOrganization> update(String id, CrmOrganizationInput body) async {
    late final dynamic res;
    try {
      res = await _client.patch(
        ApiConstants.crmOrganization(id),
        data: body.toJson(),
      );
    } on DioException catch (error) {
      _throwFriendly(error);
    }
    return CrmOrganization.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<CrmOrganization> remove(String id, String mode) async {
    late final dynamic res;
    try {
      res = await _client.post(
        ApiConstants.crmOrganizationRemove(id),
        data: {'mode': mode},
      );
    } on DioException catch (error) {
      _throwFriendly(error);
    }
    return CrmOrganization.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }
}

Never _throwFriendly(DioException error) {
  if (error.response?.statusCode == 404) {
    throw const CrmOrganizationsUnavailable();
  }
  throw error;
}

class CrmOrganizationsUnavailable implements Exception {
  const CrmOrganizationsUnavailable();

  @override
  String toString() =>
      'Organizations are not available on this server version yet.';
}
