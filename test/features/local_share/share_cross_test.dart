// Phone <-> laptop, for real: this engine against the desktop's Rust engine,
// both over loopback. Skipped unless ABX_CROSS_DIR is set — see
// ababilxdesktopcode/src-tauri/src/local_share/cross_tests.rs for how to run
// the two halves together.
import 'dart:io';
import 'dart:typed_data';

import 'package:ababilx/features/local_share/engine/client/share_client.dart';
import 'package:ababilx/features/local_share/engine/client/share_endpoint.dart';
import 'package:ababilx/features/local_share/engine/protocol/share_envelope.dart';
import 'package:ababilx/features/local_share/engine/protocol/share_file.dart';
import 'package:ababilx/features/local_share/engine/protocol/share_ids.dart';
import 'package:ababilx/features/local_share/engine/protocol/share_peer.dart';
import 'package:ababilx/features/local_share/engine/server/share_server.dart';
import 'package:ababilx/features/local_share/engine/server/share_server_context.dart';
import 'package:ababilx/features/local_share/engine/share_layout.dart';
import 'package:ababilx/features/local_share/engine/share_progress.dart';
import 'package:ababilx/features/local_share/engine/store/memory_share_store.dart';
import 'package:ababilx/features/local_share/engine/store/share_records.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _waitFor(File file) async {
  for (var i = 0; i < 600; i++) {
    if (await file.exists()) {
      final text = (await file.readAsString()).trim();
      if (text.isNotEmpty) return text;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('the Rust half never wrote ${file.path}');
}

void main() {
  final dir = Platform.environment['ABX_CROSS_DIR'];

  test(
    'Dart and Rust exchange files both ways',
    skip: dir == null ? 'set ABX_CROSS_DIR and run the Rust half' : false,
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      final root = dir!;
      final payload = File('$root/payload.bin');
      final bytes = Uint8List.fromList(
        List.generate(1500000, (i) => (i * 7) % 251),
      );
      await payload.writeAsBytes(bytes);

      final hub = ShareProgressHub();
      final store = MemoryShareStore();
      var port = 0;
      final self = SharePeer(
        deviceId: 'dart_${newShareId()}',
        name: 'Dart phone',
        deviceType: 'mobile',
        port: 1,
      );
      final server = ShareServer(
        ShareServerContext(
          store: store,
          layout: ShareLayout('$root/dart_in'),
          progress: hub,
          self: () => SharePeer(
            deviceId: self.deviceId,
            name: self.name,
            deviceType: self.deviceType,
            port: port,
          ),
          onPairRequest: (_) async => true,
        ),
        allowLoopback: true,
      );
      port = await server.start(preferredPort: 0);
      final client = ShareClient(hub);

      // 1. Dart -> Rust.
      final rustPort = int.parse(await _waitFor(File('$root/rust_port')));
      final info = await client.info(
        '127.0.0.1',
        rustPort,
        timeout: const Duration(seconds: 3),
      );
      expect(info, isNotNull, reason: 'Rust answers /info in our shape');
      final paired = await client.pair('127.0.0.1', rustPort, self);
      expect(paired.token, isNotNull, reason: 'pair: ${paired.error}');
      final to = ShareEndpoint(
        ip: '127.0.0.1',
        port: rustPort,
        token: paired.token!,
        selfDeviceId: self.deviceId,
      );
      final fileId = newShareId();
      final files = ShareEnvelope(
        id: newShareId(),
        kind: ShareKind.files,
        sentAt: DateTime.now().millisecondsSinceEpoch,
        files: [
          ShareFile(
            id: fileId,
            name: 'payload.bin',
            size: bytes.length,
            mime: 'application/octet-stream',
          ),
        ],
      );
      final sent = await client.send(to, files, {fileId: payload.path});
      expect(sent.outcome, ShareSendOutcome.done);
      final text = ShareEnvelope(
        id: newShareId(),
        kind: ShareKind.text,
        sentAt: DateTime.now().millisecondsSinceEpoch,
        text: 'from dart ✓ বাংলা',
      );
      expect((await client.send(to, text, {})).outcome, ShareSendOutcome.done);
      await File('$root/dart_port').writeAsString('$port');
      await File('$root/dart_done').writeAsString('ok');

      // 2. Rust -> Dart.
      await _waitFor(File('$root/rust_done'));
      final incoming = store.messages.values.single;
      expect(incoming.status, ShareMessageStatus.done);
      expect(incoming.text, 'from rust ✓ বাংলা');
      final row = (await store.filesOf(incoming.id)).single;
      expect(await File(row.localPath).readAsBytes(), bytes);

      client.close();
      await server.stop();
      await hub.dispose();
    },
  );
}
