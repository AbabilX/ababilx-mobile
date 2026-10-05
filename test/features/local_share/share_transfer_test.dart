import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ababilx/features/local_share/engine/client/share_client.dart';
import 'package:ababilx/features/local_share/engine/client/share_endpoint.dart';
import 'package:ababilx/features/local_share/engine/protocol/share_envelope.dart';
import 'package:ababilx/features/local_share/engine/protocol/share_file.dart';
import 'package:ababilx/features/local_share/engine/protocol/share_peer.dart';
import 'package:ababilx/features/local_share/engine/protocol/share_routes.dart';
import 'package:ababilx/features/local_share/engine/server/share_server.dart';
import 'package:ababilx/features/local_share/engine/server/share_server_context.dart';
import 'package:ababilx/features/local_share/engine/share_layout.dart';
import 'package:ababilx/features/local_share/engine/share_progress.dart';
import 'package:ababilx/features/local_share/engine/store/memory_share_store.dart';
import 'package:ababilx/features/local_share/engine/store/share_records.dart';
import 'package:flutter_test/flutter_test.dart';

const _self = SharePeer(
  deviceId: 'sender_device',
  name: 'Sender',
  deviceType: 'mobile',
  port: 1,
);
const _receiver = SharePeer(
  deviceId: 'receiver_device',
  name: 'Receiver',
  deviceType: 'desktop',
  port: 1,
);

void main() {
  late Directory tmp;
  late MemoryShareStore store;
  late ShareProgressHub hub;
  late ShareServer server;
  late ShareClient client;
  late int port;
  var accept = true;
  var asked = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('abx_share_');
    store = MemoryShareStore();
    hub = ShareProgressHub(interval: const Duration(milliseconds: 5));
    accept = true;
    asked = 0;
    server = ShareServer(
      ShareServerContext(
        store: store,
        layout: ShareLayout('${tmp.path}/in'),
        progress: hub,
        self: () => _receiver,
        onPairRequest: (_) async {
          asked++;
          return accept;
        },
      ),
      allowLoopback: true,
    );
    port = await server.start(preferredPort: 0);
    client = ShareClient(hub);
  });

  tearDown(() async {
    client.close();
    await server.stop();
    await hub.dispose();
    await tmp.delete(recursive: true);
  });

  Future<ShareEndpoint> pair() async {
    final result = await client.pair('127.0.0.1', port, _self);
    return ShareEndpoint(
      ip: '127.0.0.1',
      port: port,
      token: result.token!,
      selfDeviceId: _self.deviceId,
    );
  }

  Future<String> source(String name, int size) async {
    final file = File('${tmp.path}/out/$name');
    await file.create(recursive: true);
    await file.writeAsBytes(
      Uint8List.fromList(List.generate(size, (i) => i % 251)),
    );
    return file.path;
  }

  ShareFile meta(String id, String name, int size) => ShareFile(
    id: id,
    name: name,
    size: size,
    mime: 'application/octet-stream',
  );

  test('info answers without pairing; pairing asks the user', () async {
    expect((await client.info('127.0.0.1', port))!.name, 'Receiver');
    accept = false;
    expect((await client.pair('127.0.0.1', port, _self)).error, 'declined');
    expect(await store.device(_self.deviceId), isNull);
    accept = true;
    final ok = await client.pair('127.0.0.1', port, _self);
    expect(ok.token!.length, 64);
    expect((await store.device(_self.deviceId))!.pairToken, ok.token);
    expect(asked, 2);
  });

  test(
    'pairing again mints a new token instead of handing out the old',
    () async {
      final first = await client.pair('127.0.0.1', port, _self);
      final second = await client.pair('127.0.0.1', port, _self);
      expect(second.token, isNot(first.token));
      expect(asked, 2);
    },
  );

  test('nothing is accepted without the pair token', () async {
    final to = ShareEndpoint(
      ip: '127.0.0.1',
      port: port,
      token: 'f' * 64,
      selfDeviceId: _self.deviceId,
    );
    final envelope = ShareEnvelope(
      id: 'message_0001',
      kind: ShareKind.text,
      sentAt: 1,
      text: 'hi',
    );
    expect(
      (await client.send(to, envelope, {})).outcome,
      ShareSendOutcome.unpaired,
    );
    await pair();
    // Paired now, but this caller still holds the wrong secret.
    expect(
      (await client.send(to, envelope, {})).outcome,
      ShareSendOutcome.unpaired,
    );
    expect(store.messages, isEmpty);
  });

  test('a web page (Origin header) is refused', () async {
    final http = HttpClient();
    final request = await http.getUrl(
      Uri.parse('http://127.0.0.1:$port${ShareRoutes.info}'),
    );
    request.headers.set('origin', 'http://evil.example');
    final response = await request.close();
    expect(response.statusCode, HttpStatus.forbidden);
    await response.drain<void>();
    http.close();
  });

  test('text and files arrive, byte for byte, once', () async {
    final to = await pair();
    final a = await source('a.bin', 300000);
    final b = await source('b.bin', 0);
    final envelope = ShareEnvelope(
      id: 'message_0002',
      kind: ShareKind.files,
      sentAt: 5,
      text: 'two files',
      files: [
        meta('file_aaaa', 'a.bin', 300000),
        meta('file_bbbb', 'b.bin', 0),
      ],
    );
    final paths = {'file_aaaa': a, 'file_bbbb': b};
    expect(
      (await client.send(to, envelope, paths)).outcome,
      ShareSendOutcome.done,
    );

    final message = store.messages['message_0002']!;
    expect(message.status, ShareMessageStatus.done);
    expect(message.text, 'two files');
    expect(message.fromMe, isFalse);
    final rows = await store.filesOf('message_0002');
    expect(rows.every((f) => f.done), isTrue);
    expect(
      await File(rows[0].localPath).readAsBytes(),
      await File(a).readAsBytes(),
    );
    expect(await File(rows[1].localPath).length(), 0);
    expect(File('${rows[0].localPath}.part').existsSync(), isFalse);

    // A retry of the same id sends nothing and duplicates nothing.
    final again = await client.send(to, envelope, paths);
    expect(again.outcome, ShareSendOutcome.done);
    expect(store.messages.length, 1);
  });

  test('a dropped transfer resumes from the bytes already received', () async {
    final to = await pair();
    final path = await source('big.bin', 200000);
    final envelope = ShareEnvelope(
      id: 'message_0003',
      kind: ShareKind.files,
      sentAt: 5,
      files: [meta('file_cccc', 'big.bin', 200000)],
    );
    // Announce the message, then deliver only the first 70 000 bytes by hand.
    final http = HttpClient();
    Future<int> put(String pathAndQuery, List<int> body) async {
      final request = await http.openUrl('PUT', to.uri(pathAndQuery));
      to.sign(request);
      request.add(body);
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    }

    final post = await http.postUrl(to.uri(ShareRoutes.messages));
    to.sign(post);
    post.add(utf8.encode(envelope.encode()));
    await (await post.close()).drain<void>();
    final bytes = await File(path).readAsBytes();
    final url = ShareRoutes.file('message_0003', 'file_cccc', 0);
    expect(await put(url, bytes.sublist(0, 70000)), HttpStatus.badRequest);
    // The wrong offset is corrected, not trusted.
    expect(await put(url, bytes), HttpStatus.conflict);
    http.close();

    expect(
      store.messages['message_0003']!.status,
      ShareMessageStatus.receiving,
    );
    final result = await client.send(to, envelope, {'file_cccc': path});
    expect(result.outcome, ShareSendOutcome.done);
    final row = (await store.filesOf('message_0003')).single;
    expect(await File(row.localPath).readAsBytes(), bytes);
  });

  test('more bytes than declared fails the file', () async {
    final to = await pair();
    final path = await source('liar.bin', 5000);
    final envelope = ShareEnvelope(
      id: 'message_0004',
      kind: ShareKind.files,
      sentAt: 5,
      files: [meta('file_dddd', 'liar.bin', 100)],
    );
    final http = HttpClient();
    final post = await http.postUrl(to.uri(ShareRoutes.messages));
    to.sign(post);
    post.add(utf8.encode(envelope.encode()));
    await (await post.close()).drain<void>();
    final request = await http.openUrl(
      'PUT',
      to.uri(ShareRoutes.file('message_0004', 'file_dddd', 0)),
    );
    to.sign(request);
    request.add(await File(path).readAsBytes());
    final response = await request.close();
    await response.drain<void>();
    http.close();
    expect(response.statusCode, HttpStatus.badRequest);
    expect(store.messages['message_0004']!.status, ShareMessageStatus.failed);
    final row = (await store.filesOf('message_0004')).single;
    expect(File(row.localPath).existsSync(), isFalse);
    expect(File('${row.localPath}.part').existsSync(), isFalse);
  });

  test('delete removes only a message the caller wrote', () async {
    final to = await pair();
    final path = await source('gone.bin', 10);
    final envelope = ShareEnvelope(
      id: 'message_0005',
      kind: ShareKind.files,
      sentAt: 5,
      files: [meta('file_eeee', 'gone.bin', 10)],
    );
    await client.send(to, envelope, {'file_eeee': path});
    final stored = (await store.filesOf('message_0005')).single.localPath;
    // The receiver's own message in the same thread is not the caller's.
    await store.insertMessage(
      const ShareMessageRecord(
        id: 'message_mine',
        deviceId: 'sender_device',
        fromMe: true,
        kind: ShareKind.text,
        sentAt: 6,
        status: ShareMessageStatus.done,
        text: 'mine',
      ),
      const [],
    );
    ShareEnvelope delete(String target) => ShareEnvelope(
      id: 'delete_$target'.substring(0, 16),
      kind: ShareKind.delete,
      sentAt: 7,
      targetId: target,
    );
    await client.send(to, delete('message_mine'), {});
    expect(store.messages.containsKey('message_mine'), isTrue);
    await client.send(to, delete('message_0005'), {});
    expect(store.messages.containsKey('message_0005'), isFalse);
    expect(File(stored).existsSync(), isFalse);
  });

  test('progress is published in steps, not per chunk', () async {
    final to = await pair();
    final path = await source('p.bin', 4 * 1024 * 1024);
    final events = <ShareProgress>[];
    final sub = hub.stream.listen(events.add);
    final envelope = ShareEnvelope(
      id: 'message_0006',
      kind: ShareKind.files,
      sentAt: 5,
      files: [meta('file_ffff', 'p.bin', 4 * 1024 * 1024)],
    );
    await client.send(to, envelope, {'file_ffff': path});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(events, isNotEmpty);
    // 4 MiB is ~64 chunks on each side; a per-chunk publish would be >100.
    expect(events.length, lessThan(60));
    expect(events.last.bytes, 4 * 1024 * 1024);
  });
}
