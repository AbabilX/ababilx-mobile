import 'dart:io';

import 'package:ababilx/features/local-backup/format/backup_file_reader.dart';
import 'package:flutter_test/flutter_test.dart';

class _Collect implements BackupFileSink {
  final bytes = <int>[];
  @override
  Future<void> add(List<int> b) async => bytes.addAll(b);
  @override
  Future<void> close() async {}
}

/// A stream the desktop's TypeScript writer produced
/// (`ababilxdesktopcode/src/lib/transfer-chats/backup-writer.ts`), with the
/// same secret the desktop's own fixture uses. If this stops opening, a
/// computer can no longer send its chats to a phone.
void main() {
  test('the phone reads what the computer wrote', () async {
    final secret = List<int>.generate(32, (i) => i * 7 % 256);
    final file = File('test/fixtures/transfer_chats/desktop-v1.abxbackup');
    expect((await BackupFileReader.readHeader(file)).userId, 'user-1');
    final frames = <Map<String, dynamic>>[];
    final files = <Map<String, dynamic>>[];
    final sink = _Collect();
    await BackupFileReader(file, secret).run(
      onFrame: (f) async => frames.add(f),
      onFile: (f) async {
        files.add(f);
        return sink;
      },
    );
    expect(frames.map((f) => f['t']), ['conv', 'msg']);
    expect(frames[1]['p'], 'hello from the computer');
    expect(files.single['n'], 'doc.pdf');
    expect(files.single['s'], 3000);
    expect(sink.bytes.length, 3000);
    expect(sink.bytes[2999], 2999 * 13 % 256);
  });
}
