import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/friendly_error.dart';
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

  /// Returns null on success, or a sentence to show the user.
  ///
  /// The phone is unverified and unique, so first claimer wins; the conflict
  /// has to be named, not swallowed into "Something went wrong".
  Future<String?> savePhone(String phoneNumber) async {
    try {
      state = AsyncData(
        await ref
            .read(discoveryRepositoryProvider)
            .update(phoneNumber: phoneNumber),
      );
      return null;
    } on DioException catch (e) {
      return switch (serverErrorCode(e)) {
        'phone_already_in_use' =>
          'That number is already on another AbabilX account.',
        'phone_invalid' =>
          'Enter the number with its country code, e.g. +8801712345678.',
        _ => serverErrorMessage(e) ?? friendlyErrorMessage(e),
      };
    } catch (e) {
      return friendlyErrorMessage(e);
    }
  }
}

final discoveryProvider =
    AsyncNotifierProvider<DiscoveryNotifier, DiscoverySettings>(
      DiscoveryNotifier.new,
    );
