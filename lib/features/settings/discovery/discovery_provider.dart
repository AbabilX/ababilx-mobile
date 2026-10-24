import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'discovery_repository.dart';
import 'discovery_settings.dart';

/// The caller's own discovery identity.
///
/// Every change is written straight through and the state is replaced with
/// what the server returns, so a rejected phone number can never leave a
/// switch showing a value that was never stored.
class DiscoveryNotifier extends AsyncNotifier<DiscoverySettings> {
  @override
  Future<DiscoverySettings> build() =>
      ref.read(discoveryRepositoryProvider).get();

  Future<void> setToggle({
    bool? byUsername,
    bool? byEmail,
    bool? byPhone,
  }) async {
    final previous = state.valueOrNull;
    state = await AsyncValue.guard(
      () => ref
          .read(discoveryRepositoryProvider)
          .update(byUsername: byUsername, byEmail: byEmail, byPhone: byPhone),
    );
    // A failed toggle must not blank the screen — put the last known settings
    // back and let the caller show the error.
    if (state.hasError && previous != null) state = AsyncData(previous);
  }
}

final discoveryProvider =
    AsyncNotifierProvider<DiscoveryNotifier, DiscoverySettings>(
      DiscoveryNotifier.new,
    );
