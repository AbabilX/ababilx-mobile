import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/friendly_error.dart';
import '../profile/providers/profile_provider.dart';

/// Whether the signed-in account still owes the current privacy policy.
///
/// The server's `PolicyGate` answers 403 `policy_not_accepted` to every
/// authenticated route but a short exempt list (`/api/me` and the accept call
/// among them). `PolicyGateOverlay` asks the question for everything inside
/// the shell — but a screen that runs BEFORE the shell has no overlay over it,
/// so it must ask here or it reports a connection failure for a refusal the
/// network had nothing to do with.
///
/// A profile that cannot be read at all counts as accepted: the caller's own
/// request is about to fail anyway and will report the real reason, and a
/// policy card shown to somebody who is merely offline cannot be dismissed.
Future<bool> policyPending(WidgetRef ref) async {
  try {
    final user = await ref.read(profileProvider.future);
    return !user.acceptPolicy;
  } catch (_) {
    return false;
  }
}

/// True when [error] is the gate's own refusal.
///
/// Worth testing even after [policyPending] has passed: the profile can come
/// from this phone's cache, which predates a bump of the policy version.
bool isPolicyRefusal(Object error) =>
    serverErrorCode(error) == 'policy_not_accepted';
