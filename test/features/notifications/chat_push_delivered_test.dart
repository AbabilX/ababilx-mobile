import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/core/constants/api_constants.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/notifications/chat_push_delivered.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storage = SecureStorage(FlutterSecureStorage());
  final identity = jsonEncode({'device_id': 'dev-1', 'key_version': 1});

  Map<String, dynamic> push(String messageId, {String type = 'chat_dm'}) => {
    'type': type,
    'conversation_id': 'c1',
    'message_id': messageId,
  };

  void signedIn({String? device}) => FlutterSecureStorage.setMockInitialValues({
    StorageKeys.jwt: 'jwt',
    StorageKeys.messagingDeviceIdentity: ?device,
  });

  test('message id comes only from chat pushes', () {
    expect(chatPushMessageId(push('m1')), 'm1');
    expect(chatPushMessageId(push('m1', type: 'chat_message')), 'm1');
    expect(chatPushMessageId(push('m1', type: 'chat_mention')), 'm1');
    expect(chatPushMessageId(push('m1', type: 'voice_call')), isNull);
    expect(chatPushMessageId(push('  ')), isNull);
    expect(chatPushMessageId({'type': 'chat_dm'}), isNull);
  });

  test('device id is read out of the stored identity', () {
    expect(messagingDeviceIdFrom(identity), 'dev-1');
    expect(messagingDeviceIdFrom(null), isNull);
    expect(messagingDeviceIdFrom(''), isNull);
    expect(messagingDeviceIdFrom('not json'), isNull);
    expect(messagingDeviceIdFrom('[1]'), isNull);
    expect(messagingDeviceIdFrom(jsonEncode({'device_id': ''})), isNull);
  });

  test('sends the same delivered body as the socket path', () async {
    signedIn(device: identity);
    final sent = <Map<String, dynamic>>[];
    await postChatPushDelivered(
      push('m-body'),
      storage: storage,
      post: (_, body) async => sent.add(body),
    );
    expect(sent, [
      {
        'device_id': 'dev-1',
        'status': 'delivered',
        'message_ids': ['m-body'],
      },
    ]);
  });

  test('once per message, retried after a failure', () async {
    signedIn(device: identity);
    var calls = 0;
    var fail = true;
    Future<void> post(SecureStorage _, Map<String, dynamic> _) async {
      calls++;
      if (fail) throw Exception('offline');
    }

    await postChatPushDelivered(push('m-once'), storage: storage, post: post);
    fail = false;
    await postChatPushDelivered(push('m-once'), storage: storage, post: post);
    await postChatPushDelivered(push('m-once'), storage: storage, post: post);
    expect(calls, 2);
  });

  test('nothing is sent while signed out or unregistered', () async {
    var calls = 0;
    Future<void> post(SecureStorage _, Map<String, dynamic> _) async => calls++;

    FlutterSecureStorage.setMockInitialValues({});
    await postChatPushDelivered(push('m-out'), storage: storage, post: post);
    signedIn();
    await postChatPushDelivered(push('m-new'), storage: storage, post: post);
    signedIn(device: identity);
    await postChatPushDelivered(
      push('m-call', type: 'voice_call'),
      storage: storage,
      post: post,
    );
    expect(calls, 0);
  });
}
