import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/crm_models.dart';

/// API for the append-only customer payment ledger on a lead.
class CrmPaymentsApi {
  const CrmPaymentsApi(this._client);

  final ApiClient _client;

  Future<List<CrmLeadPayment>> list(String leadId) async {
    final res = await _client.get(ApiConstants.crmLeadPayments(leadId));
    final raw = unwrapApiData<dynamic>(res);
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        CrmLeadPayment.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  Future<CrmLeadPayment> create(String leadId, CrmLeadPaymentInput body) async {
    final res = await _client.post(
      ApiConstants.crmLeadPayments(leadId),
      data: body.toJson(),
    );
    return CrmLeadPayment.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> delete(String paymentId) =>
      _client.delete(ApiConstants.crmPayment(paymentId));
}
