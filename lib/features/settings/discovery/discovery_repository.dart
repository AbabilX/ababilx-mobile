import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'discovery_settings.dart';

class DiscoveryRepository {
  const DiscoveryRepository(this._client);

  final ApiClient _client;

  Future<DiscoverySettings> get() async {
    final res = await _client.get(ApiConstants.meDiscovery);
    return DiscoverySettings.fromJson(
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// Omitted fields keep their stored value, so each control can save on its
  /// own without racing the others.
  Future<DiscoverySettings> update({
    String? phoneNumber,
    bool? byUsername,
    bool? byEmail,
    bool? byPhone,
  }) async {
    final res = await _client.put(
      ApiConstants.meDiscovery,
      data: {
        'phone_number': ?phoneNumber,
        'discoverable_by_username': ?byUsername,
        'discoverable_by_email': ?byEmail,
        'discoverable_by_phone': ?byPhone,
      },
    );
    return DiscoverySettings.fromJson(
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }
}

final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) => DiscoveryRepository(ref.watch(apiClientProvider)),
);
