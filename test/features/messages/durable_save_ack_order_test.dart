import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/chat_utils.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/local/android_chat_message_store.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/local/chat_sidebar_cache.dart'
    show chatLocalDbProvider;
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:ababilx/features/private-chat/private_chat_api.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

// A receipt or a custody confirmation lets the server delete its copy, so
// neither may leave the phone for a message that did not reach the disk.

const _conversationId = 'conversation-1';
const _channel = MethodChannel('com.ababilx.app/chat_store');

ChatMessage _incoming({bool private = false}) => ChatMessage(
  id: 'server-id-1',
  conversationId: _conversationId,
  userId: 'peer',
  body: 'hello',
  createdAt: '2026-10-10T10:00:01Z',
  privateChat: private,
);

ApiClient _client() => ApiClient(const SecureStorage(FlutterSecureStorage()));

class _FakeRepo extends ChatRepository {
  _FakeRepo(this.log) : super(_client());

  final List<String> log;

  @override
  Future<void> acknowledgeMessages(
    String status,
    List<String> messageIds,
  ) async => log.add('ack:$status:${messageIds.join(",")}');

  @override
  Future<void> markRead(String conversationId) async {}

  @override
  Future<String> chatDeviceId() async => 'device-1';
}

class _FakeCustodyApi extends PrivateChatApi {
  _FakeCustodyApi(this.log) : super(_client());

  final List<String> log;

  @override
  Future<void> custody(String deviceId, List<String> ids) async =>
      log.add('custody:${ids.join(",")}');
}

/// The real store, with a switch that makes the durable write fail the way
/// a full or broken disk does.
class _SwitchableStore extends ChatMessageStore {
  _SwitchableStore(super.db, this.log);

  final List<String> log;
  bool broken = false;

  @override
  Future<void> saveDurable(List<ChatMessage> messages) async {
    if (broken) throw StateError('disk full');
    await super.saveDurable(messages);
    log.add('stored:${messages.map((m) => m.id).join(",")}');
  }
}

class _Notifier extends ChatNotifier {
  _Notifier(this._repo);

  final _FakeRepo _repo;

  @override
  ChatRepository get repo => _repo;

  @override
  Future<String> ensureCurrentUserId() async => 'me';

  @override
  Future<void> fetchSidebarSilent() async {}

  @override
  ChatState build() => ChatState(
    currentUserId: 'me',
    activeConversationId: _conversationId,
    feeds: {
      feedKey(_conversationId): const ChatFeed(messages: [], fetchedAt: 1),
    },
  );
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatMessageStore.saveDurable', () {
    late ChatLocalDb db;

    setUp(() => db = ChatLocalDb.forTesting(NativeDatabase.memory()));

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
      await db.close();
    });

    test('a failed native write throws, where saveAll swallows it', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            if (call.method == 'upsert') {
              throw PlatformException(code: 'chat_store_error');
            }
            return null;
          });
      final store = ChatMessageStore(
        db,
        androidStore: const AndroidChatMessageStore(),
      );
      await expectLater(
        store.saveDurable([_incoming()]),
        throwsA(isA<PlatformException>()),
      );
      // The Drift copy is still written, as the best-effort path always did.
      expect((await store.byId('server-id-1'))?.body, 'hello');
      await store.saveAll([_incoming()]);
    });

    test('a failed Drift write throws, where saveAll swallows it', () async {
      final store = ChatMessageStore(db);
      await db.customStatement('DROP TABLE cached_messages');
      await expectLater(store.saveDurable([_incoming()]), throwsA(anything));
      await store.saveAll([_incoming()]);
    });

    test('a successful write is readable', () async {
      final store = ChatMessageStore(db);
      await store.saveDurable([_incoming()]);
      expect((await store.byId('server-id-1'))?.body, 'hello');
    });
  });

  group('receipts and custody wait for the disk', () {
    late ChatLocalDb db;
    late List<String> log;
    late _SwitchableStore store;
    late ProviderContainer container;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      db = ChatLocalDb.forTesting(NativeDatabase.memory());
      log = [];
      store = _SwitchableStore(db, log);
      final repo = _FakeRepo(log);
      container = ProviderContainer(
        overrides: [
          chatLocalDbProvider.overrideWithValue(db),
          chatMessageStoreProvider.overrideWithValue(store),
          privateChatApiProvider.overrideWithValue(_FakeCustodyApi(log)),
          chatProvider.overrideWith(() => _Notifier(repo)),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    void deliver(ChatMessage message) =>
        container.read(chatProvider.notifier).handleWsEvent({
          'type': 'chat.message.created',
          'conversation_id': _conversationId,
          'message': message.toJson(),
        });

    test('a stored message is acknowledged after the write', () async {
      deliver(_incoming());
      await _settle();
      final stored = log.indexOf('stored:server-id-1');
      final delivered = log.indexOf('ack:delivered:server-id-1');
      expect(stored, isNonNegative);
      expect(delivered, greaterThan(stored));
      expect(log.indexOf('ack:read:server-id-1'), greaterThan(stored));
    });

    test('a message that was not stored is never acknowledged', () async {
      store.broken = true;
      deliver(_incoming());
      await _settle();
      expect(log.where((e) => e.startsWith('ack:')), isEmpty);
      // Still shown: the failure costs the receipt, not the message.
      expect(
        container.read(chatProvider).feedFor(_conversationId).messages,
        hasLength(1),
      );
    });

    test('custody of a private message follows the write', () async {
      deliver(_incoming(private: true));
      await _settle();
      final stored = log.indexOf('stored:server-id-1');
      final custody = log.indexOf('custody:server-id-1');
      expect(stored, isNonNegative);
      expect(custody, greaterThan(stored));
    });

    test('custody is never confirmed for a failed write', () async {
      store.broken = true;
      deliver(_incoming(private: true));
      await _settle();
      expect(log.where((e) => e.startsWith('custody:')), isEmpty);
      expect(log.where((e) => e.startsWith('ack:')), isEmpty);
    });
  });
}
