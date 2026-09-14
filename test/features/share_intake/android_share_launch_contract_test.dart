import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'external shares enter through a trampoline, not a second FlutterActivity',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      final mainStart = manifest.indexOf('android:name=".MainActivity"');
      final mainEnd = manifest.indexOf('</activity>', mainStart);
      final mainActivity = manifest.substring(mainStart, mainEnd);

      expect(mainActivity, isNot(contains('android.intent.action.SEND')));
      expect(manifest, contains('android:name=".ShareIntakeActivity"'));

      final trampoline = File(
        'android/app/src/main/kotlin/com/ababilx/app/ShareIntakeActivity.kt',
      ).readAsStringSync();
      expect(trampoline, contains('Intent.FLAG_ACTIVITY_NEW_TASK'));
      expect(trampoline, contains('Intent.FLAG_ACTIVITY_SINGLE_TOP'));
      expect(trampoline, contains('getLaunchIntentForPackage(packageName)'));
      expect(trampoline, contains('component = launchComponent'));
    },
  );
}
