import 'package:ababilx/features/policy/policy_precheck.dart';
import 'package:ababilx/features/profile/data/profile_repository.dart';
import 'package:ababilx/features/profile/providers/profile_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _me = AppUser(
  id: 'me',
  name: 'Murad',
  email: 'murad@example.com',
  provider: 'google',
);

class _Accepted extends ProfileNotifier {
  @override
  Future<AppUser> build() async => _me;
}

class _NotAccepted extends ProfileNotifier {
  @override
  Future<AppUser> build() async => _me.copyWith(acceptPolicy: false);
}

class _Unreadable extends ProfileNotifier {
  @override
  Future<AppUser> build() async => throw Exception('offline');
}

/// Runs [policyPending] with a real WidgetRef, which is the only kind the
/// call sites have.
Future<bool> _ask(WidgetTester tester, ProfileNotifier Function() profile) async {
  late Future<bool> answer;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileProvider.overrideWith(profile)],
      child: Consumer(
        builder: (_, ref, _) {
          answer = policyPending(ref);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return answer;
}

DioException _refusal() => DioException(
  requestOptions: RequestOptions(path: '/api/teams/chat/e2ee/vault'),
  response: Response(
    requestOptions: RequestOptions(path: '/api/teams/chat/e2ee/vault'),
    statusCode: 403,
    data: const {'success': false, 'error': 'policy_not_accepted'},
  ),
);

void main() {
  testWidgets('an account that owes the policy is asked before anything else', (
    tester,
  ) async {
    expect(await _ask(tester, _NotAccepted.new), isTrue);
  });

  testWidgets('an account that has accepted is not asked again', (
    tester,
  ) async {
    expect(await _ask(tester, _Accepted.new), isFalse);
  });

  testWidgets('a profile that cannot be read is not treated as a refusal', (
    tester,
  ) async {
    // Offline is not the same answer as "you have not accepted", and a card
    // shown to somebody with no network cannot be dismissed.
    expect(await _ask(tester, _Unreadable.new), isFalse);
  });

  test('the gate is recognised from the failure it returns', () {
    expect(isPolicyRefusal(_refusal()), isTrue);
    expect(
      isPolicyRefusal(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      ),
      isFalse,
    );
    expect(isPolicyRefusal(Exception('boom')), isFalse);
  });
}
