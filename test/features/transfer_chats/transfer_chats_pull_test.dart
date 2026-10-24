import 'dart:convert';
import 'dart:io';

import 'package:ababilx/features/local-backup/format/backup_file_reader.dart';
import 'package:ababilx/features/local-backup/format/backup_file_writer.dart';
import 'package:ababilx/features/transfer-chats/net/transfer_chats_client.dart';
import 'package:ababilx/features/transfer-chats/wire/transfer_chats_payload.dart';
import 'package:ababilx/features/transfer-chats/wire/transfer_chats_wire.dart';
import 'package:flutter_test/flutter_test.dart';

/// The phone's half of "from a computer" (`r=pull`) against a stand-in for
/// the computer's server (the real one is Rust, tested in
/// `src-tauri/src/transfer_chats/tests.rs`): hello, the pulled stream, the
/// reports back.
void main() {
  final secret = List<int>.generate(32, (i) => 255 - i);

  test('a pull code parses without a link key', () {
    final raw = buildTransferChatsPayload(
      TransferChatsCode(
        addresses: const ['192.168.1.9:5000'],
        secret: secret,
        linkKey: '',
        userId: 'u',
        sessionId: 'desk',
        pull: true,
      ),
    );
    expect(raw, contains('r=pull'));
    expect(raw, isNot(contains('k=')));
    final code = parseTransferChatsPayload(raw)!;
    expect(code.pull, isTrue);
    expect(code.sessionId, 'desk');
  });

  test('hello, pull, report against the computer', () async {
    final token = await transferAuthToken(secret);
    final reports = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final res = request.response;
      if (request.headers.value('authorization') != 'Bearer $token') {
        res.statusCode = 401;
        return res.close();
      }
      switch (request.uri.path) {
        case transferPathStatus:
          res.write('{"step":"waiting"}');
        case transferPathHello:
          final body = jsonDecode(await utf8.decodeStream(request)) as Map;
          if (body['session_id'] != 'phone') {
            res.statusCode = 403;
            res.write('{"error":"other_account"}');
          } else {
            res.write('{"envelope":{"ciphertext":"sealed"}}');
          }
        case transferPathStream:
          final w = await BackupFileWriter.toSink(
            res,
            key: secret,
            userId: 'u',
            createdAtMs: 1,
          );
          await w.addFrame({
            't': 'msg',
            'm': {'id': 'm1'},
            'p': 'hi',
          });
          await w.close();
          return;
        case transferPathReport:
          reports.add(
            Map<String, dynamic>.from(
              jsonDecode(await utf8.decodeStream(request)) as Map,
            ),
          );
      }
      await res.close();
    });

    final client = await TransferChatsClient.reach([
      '127.0.0.1:${server.port}',
    ], token);
    await expectLater(
      client.hello({'session_id': 'stranger'}),
      throwsA(
        isA<TransferRefused>().having((e) => e.code, 'code', 'other_account'),
      ),
    );
    final envelope = await client.hello({'session_id': 'phone'});
    expect(envelope['ciphertext'], 'sealed');

    final dir = await Directory.systemTemp.createTemp('transfer-pull');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/pulled.abxbackup');
    var seen = 0;
    await client.pullStream(file, (b) => seen = b);
    expect(seen, await file.length());
    final frames = <Map<String, dynamic>>[];
    await BackupFileReader(
      file,
      secret,
    ).run(onFrame: (f) async => frames.add(f), onFile: (_) async => null);
    expect(frames.single['p'], 'hi');

    await client.report(
      const TransferStatus(step: TransferStep.done, messages: 1),
    );
    client.close();
    expect(reports.single['step'], 'done');
    expect(reports.single['messages'], 1);
  });
}
