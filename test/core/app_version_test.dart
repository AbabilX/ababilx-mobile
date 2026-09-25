import 'dart:io';

import 'package:ababilx/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app_version.dart matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([^\s+]+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml has no version: x.y.z+N');
    expect(
      appVersionName,
      match!.group(1),
      reason: 'bump appVersionName in lib/core/app_version.dart',
    );
    expect(
      appBuildNumber,
      int.parse(match.group(2)!),
      reason: 'bump appBuildNumber in lib/core/app_version.dart',
    );
  });
}
