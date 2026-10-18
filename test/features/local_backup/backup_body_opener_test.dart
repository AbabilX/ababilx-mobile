import 'package:ababilx/features/messages/data/local/chat_key_cache.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_vault_fakes.dart';

/// The local backup opens thousands of stored messages in a row. These pin
/// the order it asks in — the phone's key, then restored text, then the
/// server ONCE per key version — because asking the server per message is
/// what made "Back up now" take minutes.
ChatMessage _sealed(
  EncryptedDmPayload payload,
  String id, {
  bool edited = false,
}) => ChatMessage(
  id: id,
  conversationId: 'chat',
  userId: 'me',
  body: '',
  createdAt: '2026-09-10T00:00:00Z',
  editedAt: edited ? '2026-09-11T00:00:00Z' : null,
  encryptedBody: payload.encryptedBody,
  encryptionNonce: payload.nonce,
  encryptionVersion: 1,
  encryptionKeyVersion: payload.keyVersion,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Two launches of one phone: two databases on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late BackupVaultRepository repo;
  late BackupVaultStorage storage;
  late ChatLocalDb db;
  late EncryptedDmPayload payload;

  setUp(() async {
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    repo = BackupVaultRepository();
    storage = BackupVaultStorage();
    final writer = MessageVault(repo, storage, ChatKeyCache(db));
    await writer.ensureIdentity();
    payload = await writer.encryptNew(
      conversationId: 'chat',
      text: 'see you at eight',
      currentUserId: 'me',
    );
  });

  /// A later launch on the same identity whose key store is empty and whose
  /// server no longer has the key — the state after "start fresh" + restore.
  Future<MessageVault> keyGone() async {
    final empty = ChatLocalDb.forTesting(NativeDatabase.memory());
    addTearDown(empty.close);
    repo.storedEnvelope = null;
    final vault = MessageVault(repo, storage, ChatKeyCache(empty));
    expect(await vault.restoreTrustedIdentity(), isTrue);
    repo.keyFetches = 0;
    repo.versionFetches = 0;
    return vault;
  }

  test('a key on the phone opens every row without the server', () async {
    final vault = MessageVault(repo, storage, ChatKeyCache(db));
    await vault.restoreTrustedIdentity();
    repo.keyFetches = 0;
    final open = vault.backupBodyOpener('me');
    final texts = await Future.wait([
      for (var i = 0; i < 40; i++) open(_sealed(payload, 'm$i')),
    ]);
    expect(texts.toSet(), {'see you at eight'});
    expect(repo.keyFetches, 0);
  });

  test('restored text answers before the server is asked at all', () async {
    final vault = await keyGone();
    vault.restoredBodyLookup = (id, _) async => 'restored $id';
    final open = vault.backupBodyOpener('me');
    final texts = await Future.wait([
      for (var i = 0; i < 40; i++) open(_sealed(payload, 'm$i')),
    ]);
    expect(texts.first, 'restored m0');
    expect(texts.last, 'restored m39');
    expect(repo.keyFetches + repo.versionFetches, 0);
  });

  test(
    'a version nobody holds costs one server round, not one per row',
    () async {
      final vault = await keyGone();
      final open = vault.backupBodyOpener('me');
      final first = await Future.wait([
        for (var i = 0; i < 40; i++) open(_sealed(payload, 'm$i')),
      ]);
      final later = await open(_sealed(payload, 'late'));
      expect(first.every((t) => t == null), isTrue);
      expect(later, isNull);
      expect(repo.keyFetches, lessThanOrEqualTo(1));
      expect(repo.versionFetches, lessThanOrEqualTo(1));
    },
  );

  test(
    'an edited row asks the server once, then takes its restored text',
    () async {
      final vault = await keyGone();
      vault.restoredBodyLookup = (id, _) async => 'restored $id';
      final open = vault.backupBodyOpener('me');
      final text = await open(_sealed(payload, 'e1', edited: true));
      expect(text, 'restored e1');
      expect(repo.keyFetches + repo.versionFetches, greaterThan(0));
    },
  );

  test(
    'plain rows come back as they are; a locked vault opens nothing',
    () async {
      final vault = MessageVault(repo, storage, ChatKeyCache(db));
      final open = vault.backupBodyOpener('me');
      final plain = ChatMessage(
        id: 'p',
        conversationId: 'chat',
        userId: 'me',
        body: 'hello',
        createdAt: '2026-09-10T00:00:00Z',
      );
      expect(await open(plain), 'hello');
      expect(await open(_sealed(payload, 'locked')), isNull);
    },
  );
}
