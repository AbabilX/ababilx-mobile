import 'package:dio/dio.dart';

import 'friendly_error.dart';

/// The server's answer when an action needs a sign-in made just now, not
/// just a token that still works (replacing a message identity is one).
const recentSignInRequiredCode = 'recent_sign_in_required';

/// Exactly that refusal: HTTP 403 carrying [recentSignInRequiredCode]. Any
/// other 403 (the policy gate, a permission) is someone else's business.
bool isRecentSignInRequired(Object error) =>
    error is DioException &&
    error.response?.statusCode == 403 &&
    serverErrorCode(error) == recentSignInRequiredCode;

/// What one attempt to sign in again came to.
enum ReauthOutcome {
  /// A real sign-in happened; the stored tokens now belong to it.
  signedIn,

  /// The person backed out of the sign-in (closed the Google picker).
  cancelled,

  /// The sign-in was refused, or it was a different account.
  failed,

  /// No answer — offline, timeout, 5xx. Trying again later may work.
  unavailable,

  /// This account has no sign-in the phone can run by itself (email +
  /// password): the person has to sign in again themselves.
  notSupported,
}

/// The action still needs a recent sign-in after [withRecentSignIn] did what
/// it could. Carries how the sign-in attempt ended, so the screen can say
/// the right thing.
class RecentSignInRequired implements Exception {
  const RecentSignInRequired(this.outcome);
  final ReauthOutcome outcome;

  @override
  String toString() => 'RecentSignInRequired(${outcome.name})';
}

/// Runs [request]. If the server refuses it for want of a recent sign-in,
/// asks [reauthenticate] for a genuine one and runs [request] ONE more time.
/// There is never a second sign-in and never a third request: a refusal after
/// a successful sign-in becomes [RecentSignInRequired] instead of a loop.
Future<T> withRecentSignIn<T>({
  required Future<T> Function() request,
  required Future<ReauthOutcome> Function() reauthenticate,
}) async {
  try {
    return await request();
  } catch (error) {
    if (!isRecentSignInRequired(error)) rethrow;
  }
  final outcome = await reauthenticate();
  if (outcome != ReauthOutcome.signedIn) throw RecentSignInRequired(outcome);
  try {
    return await request();
  } catch (error) {
    if (isRecentSignInRequired(error)) {
      throw const RecentSignInRequired(ReauthOutcome.signedIn);
    }
    rethrow;
  }
}
