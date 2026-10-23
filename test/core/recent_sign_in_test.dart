import 'package:ababilx/core/network/recent_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _refusal(int status, String code) {
  final options = RequestOptions(path: '/api/chat/recovery/start-session');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: {'success': false, 'error': code},
    ),
  );
}

final _needsSignIn = _refusal(403, recentSignInRequiredCode);

/// A request that answers from a script, one entry per call.
class _Script {
  _Script(this.answers);
  final List<Object> answers;
  int calls = 0;

  Future<String> call() async {
    final answer = answers[calls++];
    if (answer is String) return answer;
    throw answer;
  }
}

class _Reauth {
  _Reauth(this.outcome);
  final ReauthOutcome outcome;
  int calls = 0;

  Future<ReauthOutcome> call() async {
    calls++;
    return outcome;
  }
}

void main() {
  test('a request that succeeds never signs in', () async {
    final request = _Script(['ok']);
    final reauth = _Reauth(ReauthOutcome.signedIn);
    expect(
      await withRecentSignIn(
        request: request.call,
        reauthenticate: reauth.call,
      ),
      'ok',
    );
    expect(request.calls, 1);
    expect(reauth.calls, 0);
  });

  test('a successful sign-in retries the request once', () async {
    final request = _Script([_needsSignIn, 'ok']);
    final reauth = _Reauth(ReauthOutcome.signedIn);
    expect(
      await withRecentSignIn(
        request: request.call,
        reauthenticate: reauth.call,
      ),
      'ok',
    );
    expect(request.calls, 2);
    expect(reauth.calls, 1);
  });

  for (final outcome in [
    ReauthOutcome.cancelled,
    ReauthOutcome.failed,
    ReauthOutcome.unavailable,
    ReauthOutcome.notSupported,
  ]) {
    test('a sign-in that ends ${outcome.name} does not retry', () async {
      final request = _Script([_needsSignIn, 'never']);
      final reauth = _Reauth(outcome);
      await expectLater(
        withRecentSignIn(request: request.call, reauthenticate: reauth.call),
        throwsA(
          isA<RecentSignInRequired>().having(
            (e) => e.outcome,
            'outcome',
            outcome,
          ),
        ),
      );
      expect(request.calls, 1);
      expect(reauth.calls, 1);
    });
  }

  test('a second refusal after signing in stops: no loop', () async {
    final request = _Script([_needsSignIn, _needsSignIn, 'never']);
    final reauth = _Reauth(ReauthOutcome.signedIn);
    await expectLater(
      withRecentSignIn(request: request.call, reauthenticate: reauth.call),
      throwsA(isA<RecentSignInRequired>()),
    );
    expect(request.calls, 2, reason: 'at most one retry');
    expect(reauth.calls, 1, reason: 'at most one sign-in');
  });

  test('another failure on the retry is passed through as it is', () async {
    final conflict = _refusal(409, 'message identity changed; check again');
    final request = _Script([_needsSignIn, conflict]);
    await expectLater(
      withRecentSignIn(
        request: request.call,
        reauthenticate: _Reauth(ReauthOutcome.signedIn).call,
      ),
      throwsA(same(conflict)),
    );
  });

  for (final other in [
    _refusal(403, 'policy_not_accepted'),
    _refusal(401, 'unauthorized'),
    _refusal(409, recentSignInRequiredCode),
    _refusal(500, 'could not start session'),
  ]) {
    test('${other.response!.statusCode} ${other.response!.data['error']} '
        'never triggers a sign-in', () async {
      final request = _Script([other]);
      final reauth = _Reauth(ReauthOutcome.signedIn);
      await expectLater(
        withRecentSignIn(request: request.call, reauthenticate: reauth.call),
        throwsA(same(other)),
      );
      expect(reauth.calls, 0);
      expect(request.calls, 1);
    });
  }

  test('isRecentSignInRequired matches only the 403 with that code', () {
    expect(isRecentSignInRequired(_needsSignIn), isTrue);
    expect(
      isRecentSignInRequired(_refusal(403, 'policy_not_accepted')),
      isFalse,
    );
    expect(isRecentSignInRequired(StateError('x')), isFalse);
  });
}
