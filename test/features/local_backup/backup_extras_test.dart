import 'dart:convert';

import 'package:ababilx/features/calls/data/models/call_log_entry.dart';
import 'package:ababilx/features/calls/data/restored_call_log.dart';
import 'package:ababilx/features/local-backup/extras/backup_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

CallLogEntry call(String id, int day) => CallLogEntry.fromJson({
  'id': id,
  'kind': 'voice',
  'started_at': DateTime.utc(2026, 9, day).toIso8601String(),
});

void main() {
  group('withRestoredCalls', () {
    final server = [call('a', 20), call('b', 10)];
    final restored = [call('b', 10), call('c', 15), call('d', 1)];

    test('more pages to come: only rows inside the loaded span join', () {
      final out = withRestoredCalls(server, restored, hasMore: true);
      expect(out.map((c) => c.id), ['a', 'c', 'b']);
    });

    test('server done (or offline, empty): every restored row joins', () {
      expect(
        withRestoredCalls(server, restored, hasMore: false).map((c) => c.id),
        ['a', 'c', 'b', 'd'],
      );
      expect(
        withRestoredCalls(const [], restored, hasMore: false).map((c) => c.id),
        ['c', 'b', 'd'],
      );
    });
  });

  group('restoredLockIndex', () {
    test('a password lock comes back as the phone lock', () {
      final out = restoredLockIndex(
        jsonEncode({'x': 'password', 'y': 'device'}),
        null,
      );
      expect(jsonDecode(out!), {'x': 'device', 'y': 'device'});
    });

    test('the phone keeps its own entries', () {
      final out = restoredLockIndex(
        jsonEncode({'x': 'password'}),
        jsonEncode({'x': 'password', 'z': 'device'}),
      );
      expect(jsonDecode(out!), {'x': 'password', 'z': 'device'});
    });
  });

  test('settings allowlist keeps install-specific keys out', () {
    expect(BackupPrefs.allowed('ababilx_theme_mode'), isTrue);
    expect(BackupPrefs.allowed('auto_download_photo'), isTrue);
    expect(BackupPrefs.allowed('ababilx_chat_wallpaper_abc'), isTrue);
    expect(BackupPrefs.allowed('device_identity_v1'), isFalse);
    expect(BackupPrefs.allowed('permission_intro_v1'), isFalse);
    expect(BackupPrefs.allowed('call_log_cache_v1'), isFalse);
  });
}
