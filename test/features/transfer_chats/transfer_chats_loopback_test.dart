import 'dart:io';

import 'package:ababilx/features/local-backup/format/backup_file_reader.dart';
import 'package:ababilx/features/local-backup/format/backup_file_writer.dart';
import 'package:ababilx/features/transfer-chats/net/transfer_chats_client.dart';
import 'package:ababilx/features/transfer-chats/net/transfer_chats_server.dart';
import 'package:ababilx/features/transfer-chats/wire/transfer_chats_wire.dart';
import 'package:flutter_test/flutter_test.dart';

class _Collect implements BackupFileSink {
  final bytes = <int>[];
  @override
  Future<void> add(List<int> b) async => bytes.addAll(b);
  @override
  Future<void> close() async {}
}

/// The old phone writes the backup stream into the network and the new one
/// reads it back with the restore reader: the whole transport, over loopback.
void main() {
  late Directory dir;
  late List<int> secret;
  late String token;
  late TransferChatsServer server;
  late Future<File> received;
  Map<String, dynamic>? identity;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('transfer-chats-test');
    secret = List<int>.generate(32, (i) => 255 - i);
    token = await transferAuthToken(secret);
    final done = <File>[];
    identity = null;
    server = TransferChatsServer(
      token: token,
      onIdentity: (e) async {
        if (e['ciphertext'] == 'bad') throw StateError('does not open');
        identity = e;
      },
      streamFile: () async => File('${dir.path}/in.abxbackup'),
      onReceived: (f) async => done.add(f),
      status: () => const TransferStatus(),
      allowLoopback: true,
    );
    final port = await server.start();
    received = () async {
      while (done.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return done.single;
    }();
    addTearDown(() async {
      await server.stop();
      await dir.delete(recursive: true);
    });
    expect(port, greaterThan(0));
  });

  Future<TransferChatsClient> reach([String? withToken]) =>
      TransferChatsClient.reach([
        '127.0.0.1:${server.port}',
      ], withToken ?? token);

  test('identity, then the sealed stream, read back intact', () async {
    final client = await reach();
    await client.sendIdentity({'ciphertext': 'sealed'});
    expect(identity, {'ciphertext': 'sealed'});

    final photo = File('${dir.path}/photo.jpg')
      ..writeAsBytesSync(List<int>.generate(700 * 1024, (i) => i % 251));
    final request = await client.openStream();
    final writer = await BackupFileWriter.toSink(
      request,
      key: secret,
      userId: 'user-1',
      createdAtMs: 1,
    );
    await writer.addFrame({
      't': 'msg',
      'm': {'id': 'm1'},
      'p': 'hello',
    });
    await writer.addFile({'u': 'https://cdn/x', 'n': 'photo.jpg'}, photo);
    await writer.close();
    await client.finishStream(request);
    client.close();

    final file = await received;
    expect((await BackupFileReader.readHeader(file)).userId, 'user-1');
    final frames = <Map<String, dynamic>>[];
    final sink = _Collect();
    await BackupFileReader(
      file,
      secret,
    ).run(onFrame: (f) async => frames.add(f), onFile: (f) async => sink);
    expect(frames.single['p'], 'hello');
    expect(sink.bytes, photo.readAsBytesSync());
  });

  test('a stranger without the token is not let in', () async {
    final wrong = await transferAuthToken(List<int>.filled(32, 1));
    await expectLater(reach(wrong), throwsA(isA<TransferUnreachable>()));
  });

  test('no stream before the message key, and a bad key is refused', () async {
    final client = await reach();
    final early = await client.openStream();
    early.add([1, 2, 3]);
    final refused = await early.close();
    await refused.drain<void>();
    expect(refused.statusCode, HttpStatus.conflict);
    await expectLater(
      client.sendIdentity({'ciphertext': 'bad'}),
      throwsA(isA<TransferRefused>()),
    );
    await client.sendIdentity({'ciphertext': 'good'});
    await expectLater(
      client.sendIdentity({'ciphertext': 'again'}),
      throwsA(isA<TransferRefused>()),
    );
    client.close();
  });

  test('another key cannot read the stream', () async {
    final client = await reach();
    await client.sendIdentity({'ciphertext': 'sealed'});
    final request = await client.openStream();
    final writer = await BackupFileWriter.toSink(
      request,
      key: secret,
      userId: 'user-1',
      createdAtMs: 1,
    );
    await writer.addFrame({
      't': 'msg',
      'm': {'id': 'm1'},
    });
    await writer.close();
    await client.finishStream(request);
    client.close();
    final file = await received;
    await expectLater(
      BackupFileReader(
        file,
        List<int>.filled(32, 9),
      ).run(onFrame: (_) async {}, onFile: (_) async => null),
      throwsA(anything),
    );
  });
}
