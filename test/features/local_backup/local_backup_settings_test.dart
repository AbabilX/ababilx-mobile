import 'package:ababilx/features/local-backup/data/local_backup_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings: on by default, an old untouched "off" becomes on, '
      'a choice is kept', () {
    LocalBackupSettings read(Map<String, dynamic>? json) =>
        LocalBackupSettings.fromStored(json, automatic: true);
    expect(read(null).enabled, isTrue);
    expect(read(null).hasFolder, isFalse);
    // Saved before 2026-10-08 by someone who only changed a media switch.
    expect(
      read({'enabled': false, 'choices': <String, dynamic>{}}).enabled,
      isTrue,
    );
    // Turned off under today's rule: stays off.
    expect(read(const LocalBackupSettings().toJson()).enabled, isFalse);
    // A picked folder is a choice, on or off.
    final picked = read({'enabled': true, 'folder_uri': 'content://x'});
    expect(picked.enabled && picked.hasFolder, isTrue);
    expect(
      LocalBackupSettings.fromStored(null, automatic: false).enabled,
      isFalse,
    );
  });
}
