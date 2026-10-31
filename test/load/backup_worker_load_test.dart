@Timeout(Duration(minutes: 20))
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ababilx/features/local-backup/format/backup_crypto.dart';
import 'package:ababilx/features/local-backup/format/backup_errors.dart';
import 'package:ababilx/features/local-backup/format/backup_file_reader.dart';
import 'package:ababilx/features/local-backup/format/backup_file_writer.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1000+ simulated accounts backing up and restoring through the background
/// record worker. Off by default: `LOAD=1 flutter test test/load`.
///
/// Checks: every account restores exactly its own data; no key opens another
/// account's file; a tampered file is refused; memory settles; and the UI
/// isolate's event loop keeps turning while records are sealed.
const _users = 1000;
const _parallel = 16;
const _framesPerUser = 20;

class _Sink implements BackupFileSink {
  final bytes = BytesBuilder(copy: false);
  @override
  Future<void> add(List<int> b) async => bytes.add(b);
  @override
  Future<void> close() async {}
}

class _User {
  _User(this.index, Random random)
    : key = List<int>.generate(32, (_) => random.nextInt(256)),
      id = 'user-$index',
      media = Uint8List.fromList(
        List<int>.generate(
          // Every tenth account has a 1.2 MB photo: three file parts.
          index % 10 == 0 ? 1200 * 1024 : 4096,
          (i) => (i * 31 + index) % 256,
        ),
      );

  final int index;
  final List<int> key;
  final String id;
  final Uint8List media;
  late File file;

  String text(int i) => 'secret $id #$i';
}

/// Longest the event loop went without running a 4 ms timer.
class _LoopWatch {
  final _clock = Stopwatch()..start();
  late final Timer _timer;
  int _last = 0;
  int maxGapMs = 0;

  _LoopWatch() {
    _timer = Timer.periodic(const Duration(milliseconds: 4), (_) {
      final now = _clock.elapsedMilliseconds;
      maxGapMs = max(maxGapMs, now - _last);
      _last = now;
    });
  }

  /// Counts the gap still open: a loop that never let the timer run at all
  /// is one long gap, not zero.
  void stop() {
    _timer.cancel();
    maxGapMs = max(maxGapMs, _clock.elapsedMilliseconds - _last);
  }
}

Future<void> _pool<T>(List<T> items, Future<void> Function(T) run) async {
  var next = 0;
  Future<void> lane() async {
    while (next < items.length) {
      await run(items[next++]);
    }
  }

  await Future.wait(List.generate(_parallel, (_) => lane()));
}

int _rssMb() => ProcessInfo.currentRss ~/ (1024 * 1024);

void main() {
  final enabled = Platform.environment['LOAD'] == '1';
  late Directory dir;
  final random = Random(42);
  final users = List.generate(_users, (i) => _User(i, random));

  setUpAll(() => dir = Directory.systemTemp.createTempSync('backup_load'));
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('1000 accounts back up and restore through the worker', () async {
    final rssStart = _rssMb();
    final clock = Stopwatch()..start();
    final writeWatch = _LoopWatch();
    await _pool(users, (u) async {
      u.file = File('${dir.path}/${u.id}.abxbackup');
      final source = File('${dir.path}/${u.id}.jpg')
        ..writeAsBytesSync(u.media);
      final writer = await BackupFileWriter.create(
        u.file,
        accountKey: u.key,
        userId: u.id,
        createdAtMs: 1,
      );
      for (var i = 0; i < _framesPerUser; i++) {
        await writer.addFrame({
          't': 'msg',
          'm': {'id': '${u.id}-$i'},
          'p': u.text(i),
        });
      }
      await writer.addFile({'u': 'https://cdn/${u.id}.jpg'}, source);
      await writer.close();
    });
    writeWatch.stop();
    final writeMs = clock.elapsedMilliseconds;
    final rssAfterWrite = _rssMb();

    clock.reset();
    final readWatch = _LoopWatch();
    var restored = 0;
    await _pool(users, (u) async {
      final texts = <String>[];
      final sink = _Sink();
      await BackupFileReader(u.file, u.key).run(
        onFrame: (f) async => texts.add(f['p'] as String),
        onFile: (_) async => sink,
      );
      expect(texts, [for (var i = 0; i < _framesPerUser; i++) u.text(i)]);
      expect(sink.bytes.takeBytes(), u.media);
      restored++;
    });
    readWatch.stop();
    final readMs = clock.elapsedMilliseconds;
    expect(restored, _users);

    // No account's key opens another account's file.
    var refused = 0;
    await _pool(users, (u) async {
      final other = users[(u.index + 1) % _users];
      try {
        await BackupFileReader(u.file, other.key).run(
          onFrame: (_) async {},
          onFile: (_) async => null,
        );
      } on BackupWrongAccountError {
        refused++;
      }
    });
    expect(refused, _users);

    // A flipped byte anywhere past the header is refused, never half-read.
    var damaged = 0;
    final tampered = users.where((u) => u.index % 10 == 0).toList();
    await _pool(tampered, (u) async {
      final bytes = u.file.readAsBytesSync();
      bytes[bytes.length - 40] ^= 0x01;
      final copy = File('${u.file.path}.bad')..writeAsBytesSync(bytes);
      try {
        await BackupFileReader(copy, u.key).run(
          onFrame: (_) async {},
          onFile: (_) async => _Sink(),
        );
      } on BackupDamagedError {
        damaged++;
      }
    });
    expect(damaged, tampered.length);

    final rssEnd = _rssMb();
    // ignore: avoid_print
    print(
      '[load] users=$_users parallel=$_parallel '
      'write=${writeMs}ms read=${readMs}ms '
      'loopMaxGap write=${writeWatch.maxGapMs}ms read=${readWatch.maxGapMs}ms '
      'rss start=${rssStart}MB afterWrite=${rssAfterWrite}MB end=${rssEnd}MB '
      'wrongKeyRefused=$refused tamperedRefused=$damaged',
    );
    expect(rssEnd - rssStart, lessThan(400), reason: 'memory must settle');
  }, skip: enabled ? false : 'set LOAD=1');

  test('the worker keeps the event loop turning; sealing inline does not', () async {
    final key = List<int>.generate(32, (i) => i);
    final part = Uint8List(512 * 1024);
    const records = 40; // 20 MB, a short video
    final aad = BackupCrypto.recordAad('d', 0);

    final inline = _LoopWatch();
    final inlineClock = Stopwatch()..start();
    for (var i = 0; i < records; i++) {
      await BackupCrypto.seal(SecretKey(key), aad, part);
    }
    inline.stop();

    final worker = _LoopWatch();
    final workerClock = Stopwatch()..start();
    final file = File('${dir.path}/video.abxbackup');
    final source = File('${dir.path}/video.bin')
      ..writeAsBytesSync(Uint8List(records * part.length));
    final writer = await BackupFileWriter.create(
      file,
      accountKey: key,
      userId: 'v',
      createdAtMs: 1,
    );
    await writer.addFile({'u': 'https://cdn/v.mp4'}, source);
    await writer.close();
    worker.stop();

    // ignore: avoid_print
    print(
      '[load] 20MB seal: inline ${inlineClock.elapsedMilliseconds}ms '
      'maxGap=${inline.maxGapMs}ms | worker '
      '${workerClock.elapsedMilliseconds}ms maxGap=${worker.maxGapMs}ms',
    );
    expect(worker.maxGapMs, lessThan(inline.maxGapMs));
    expect(worker.maxGapMs, lessThan(100));
  }, skip: enabled ? false : 'set LOAD=1');
}
