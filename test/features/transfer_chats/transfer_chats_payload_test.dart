import 'package:ababilx/features/transfer-chats/wire/transfer_chats_payload.dart';
import 'package:ababilx/features/transfer-chats/wire/transfer_chats_wire.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final secret = List<int>.generate(32, (i) => i);
  TransferChatsCode code({List<String>? addresses}) => TransferChatsCode(
    addresses: addresses ?? ['192.168.1.20:41234', '10.0.0.5:41234'],
    secret: secret,
    linkKey: 'eyJjcnYiOiJQLTI1NiJ9',
    userId: 'user-1',
    sessionId: 'session-1',
  );

  test('a built code parses back to the same fields', () {
    final raw = buildTransferChatsPayload(code());
    expect(raw, startsWith('ababilx://transfer-chats?v=1&'));
    expect(isTransferChatsPayload(raw), isTrue);
    final back = parseTransferChatsPayload(raw)!;
    expect(back.addresses, ['192.168.1.20:41234', '10.0.0.5:41234']);
    expect(back.secret, secret);
    expect(back.linkKey, 'eyJjcnYiOiJQLTI1NiJ9');
    expect(back.userId, 'user-1');
    expect(back.sessionId, 'session-1');
  });

  test('anything incomplete or foreign is refused', () {
    final good = buildTransferChatsPayload(code());
    String without(String key) =>
        good.replaceAll(RegExp('[?&]$key=[^&]*'), key == 'v' ? '?' : '');
    expect(parseTransferChatsPayload('ababilx://user?u=murad'), isNull);
    expect(parseTransferChatsPayload(good.replaceFirst('v=1', 'v=2')), isNull);
    expect(parseTransferChatsPayload(without('sid')), isNull);
    expect(parseTransferChatsPayload(without('k')), isNull);
    final short = buildTransferChatsPayload(
      TransferChatsCode(
        addresses: const ['192.168.1.20:1'],
        secret: const [1, 2, 3],
        linkKey: 'k',
        userId: 'u',
        sessionId: 's',
      ),
    );
    expect(parseTransferChatsPayload(short), isNull);
  });

  test('only IPv4 addresses with a port are kept', () {
    expect(isTransferAddress('192.168.1.20:41234'), isTrue);
    expect(isTransferAddress('evil.example.com:80'), isFalse);
    expect(isTransferAddress('300.1.1.1:80'), isFalse);
    expect(isTransferAddress('192.168.1.20'), isFalse);
    expect(isTransferAddress('192.168.1.20:0'), isFalse);
    final mixed = parseTransferChatsPayload(
      buildTransferChatsPayload(
        code(addresses: ['evil.example.com:80', '192.168.1.20:5']),
      ),
    )!;
    expect(mixed.addresses, ['192.168.1.20:5']);
  });

  test('the token is fixed for a secret and compared exactly', () async {
    final a = await transferAuthToken(secret);
    expect(await transferAuthToken(secret), a);
    expect(await transferAuthToken(List<int>.filled(32, 7)), isNot(a));
    expect(sameTransferToken(a, a), isTrue);
    expect(sameTransferToken(a, '${a}x'), isFalse);
    expect(sameTransferToken(a, a.replaceRange(0, 1, '!')), isFalse);
  });

  test('status survives the wire, an unknown step reads as failed', () {
    const status = TransferStatus(
      step: TransferStep.importing,
      bytes: 10,
      messages: 4,
      files: 2,
    );
    final back = TransferStatus.fromJson(status.toJson());
    expect(back.step, TransferStep.importing);
    expect(back.messages, 4);
    expect(TransferStatus.fromJson({'step': 'nope'}).step, TransferStep.failed);
  });
}
