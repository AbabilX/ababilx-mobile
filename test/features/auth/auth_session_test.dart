import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/auth/data/auth_session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySecureStorage extends SecureStorage {
  _MemorySecureStorage() : super(const FlutterSecureStorage());

  String? jwt = 'jwt';
  String? refresh = 'refresh';
  String? owner = 'user-1';
  String? identity = 'private-key-envelope';

  @override
  Future<void> deleteJwt() async => jwt = null;

  @override
  Future<void> deleteRefreshToken() async => refresh = null;

  @override
  Future<String?> readLocalDataOwnerUserId() async => owner;

  @override
  Future<String?> readMessageVaultIdentity() async => identity;
}

void main() {
  group('local account ownership', () {
    test('a clean install accepts the first account', () {
      expect(
        decideLocalAccount(newUserId: 'user-1'),
        LocalAccountDecision.firstAccount,
      );
    });

    test('the stored owner can reopen its archive', () {
      expect(
        decideLocalAccount(newUserId: 'user-1', storedOwnerUserId: 'user-1'),
        LocalAccountDecision.sameAccount,
      );
    });

    test('a legacy cached owner can reopen its archive', () {
      expect(
        decideLocalAccount(newUserId: 'user-1', cachedOwnerUserId: 'user-1'),
        LocalAccountDecision.sameAccount,
      );
    });

    test('a different account requires a destructive switch', () {
      expect(
        decideLocalAccount(newUserId: 'user-2', storedOwnerUserId: 'user-1'),
        LocalAccountDecision.switchAccount,
      );
    });

    test('an unowned legacy identity requires confirmation', () {
      expect(
        decideLocalAccount(newUserId: 'user-1', hasUnownedPrivateData: true),
        LocalAccountDecision.switchAccount,
      );
    });

    test('stored owner takes precedence over stale profile cache', () {
      expect(
        decideLocalAccount(
          newUserId: 'user-1',
          storedOwnerUserId: 'user-2',
          cachedOwnerUserId: 'user-1',
        ),
        LocalAccountDecision.switchAccount,
      );
    });
  });

  test('auth-only clear preserves owner and encryption identity', () async {
    final storage = _MemorySecureStorage();

    await storage.clearAuthSession();

    expect(storage.jwt, isNull);
    expect(storage.refresh, isNull);
    expect(await storage.readLocalDataOwnerUserId(), 'user-1');
    expect(await storage.readMessageVaultIdentity(), 'private-key-envelope');
  });

  test('prepared session uses email as the switch warning label', () {
    const session = PreparedAuthSession(
      accessToken: 'jwt',
      userId: 'user-2',
      user: {'email': 'new@example.com', 'name': 'New User'},
    );
    expect(session.accountLabel, 'new@example.com');
  });
}
