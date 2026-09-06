import 'dart:typed_data';

import 'package:ababilx/features/messages/archive/archive_api.dart';
import 'package:ababilx/features/messages/archive/archive_exporter.dart';
import 'package:ababilx/features/messages/archive/archive_importer.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the server and the object store. Chunks land in a map keyed by
/// their upload URL, which is all the exporter and importer ever need of it.
class _FakeArchiveApi implements ArchiveApi {
  final Map<String, List<int>> objects = {};
  final List<String> order = [];
  int generation = 0;
  String? salt;
  int? committedChunks;

  @override
  Future<int> begin(String saltValue) async {
    salt = saltValue;
    return ++generation;
  }

  @override
  Future<String> presignChunk({
    required int generation,
    required int index,
    required int sizeBytes,
  }) async => 'obj://$generation/$index';

  @override
  Future<void> putChunk(String uploadUrl, List<int> bytes) async {
    objects[uploadUrl] = bytes;
    order.add(uploadUrl);
  }

  @override
  Future<void> commit({
    required int generation,
    required int chunkCount,
    required int totalBytes,
    required int formatVersion,
  }) async => committedChunks = chunkCount;

  @override
  Future<List<int>> getChunk(String url) async => objects[url]!;

  @override
  Future<ArchiveManifest?> fetchManifest() async => ArchiveManifest(
    generation: generation,
    salt: salt!,
    formatVersion: 1,
    chunkCount: order.length,
    totalBytes: 0,
    chunks: List<String>.from(order),
  );
}

ChatMessage _msg(int i) => ChatMessage(
  id: 'm${i.toString().padLeft(4, '0')}',
  conversationId: 'c1',
  userId: 'u1',
  body: 'body $i',
  createdAt: '2026-09-07T00:00:00.000Z',
  // Every seventh message is a thread reply. `page` cannot see these, so if the
  // exporter ever regresses to using it, this count drops and the test fails.
  parentId: i % 7 == 0 && i > 0 ? 'm0000' : null,
);

void main() {
  late ChatLocalDb source;
  late ChatLocalDb restored;

  setUp(() {
    source = ChatLocalDb.forTesting(NativeDatabase.memory());
    restored = ChatLocalDb.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await source.close();
    await restored.close();
  });

  test('a history exports and restores onto a fresh device', () async {
    final scalar = Uint8List.fromList(
      List<int>.generate(32, (i) => i * 3 % 251),
    );
    final api = _FakeArchiveApi();
    final from = ChatMessageStore(source);
    final to = ChatMessageStore(restored);

    final all = List.generate(1200, _msg);
    await from.saveAll(all);

    final result = await ArchiveExporter(
      store: from,
      api: api,
      identityScalar: scalar,
    ).run(deviceId: 'dev-1', createdAtMs: 1);

    expect(result.frames, greaterThanOrEqualTo(all.length));
    expect(api.committedChunks, result.chunks);

    // The restoring device starts empty.
    expect(await to.page('c1', limit: 10), isEmpty);

    final imported = await ArchiveImporter(
      store: to,
      api: api,
      identityScalar: scalar,
    ).run((await api.fetchManifest())!);

    expect(imported.restored, all.length);

    // Every row is back, threads included — which is the whole point of
    // exporting through exportPage rather than page.
    final everything = await to.exportPage(limit: 2000);
    expect(everything.length, all.length);
    expect(
      everything.where((m) => m.parentId != null).length,
      all.where((m) => m.parentId != null).length,
    );
  });

  test('restoring twice converges instead of duplicating', () async {
    final scalar = Uint8List.fromList(List<int>.filled(32, 9));
    final api = _FakeArchiveApi();
    final from = ChatMessageStore(source);
    final to = ChatMessageStore(restored);
    await from.saveAll(List.generate(50, _msg));

    await ArchiveExporter(
      store: from,
      api: api,
      identityScalar: scalar,
    ).run(deviceId: 'dev-1', createdAtMs: 1);
    final manifest = (await api.fetchManifest())!;
    final importer = ArchiveImporter(
      store: to,
      api: api,
      identityScalar: scalar,
    );
    await importer.run(manifest);
    await importer.run(manifest);

    // Merge by server id, so a re-run of an interrupted restore is safe.
    expect((await to.exportPage(limit: 2000)).length, 50);
  });

  test('a wrong identity cannot open the archive', () async {
    final api = _FakeArchiveApi();
    final from = ChatMessageStore(source);
    await from.saveAll(List.generate(20, _msg));
    await ArchiveExporter(
      store: from,
      api: api,
      identityScalar: Uint8List.fromList(List<int>.filled(32, 1)),
    ).run(deviceId: 'dev-1', createdAtMs: 1);

    final importer = ArchiveImporter(
      store: ChatMessageStore(restored),
      api: api,
      identityScalar: Uint8List.fromList(List<int>.filled(32, 2)),
    );
    await expectLater(
      importer.run((await api.fetchManifest())!),
      throwsA(anything),
    );
  });
}
