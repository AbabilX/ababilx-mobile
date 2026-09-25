import 'dart:convert';
import 'dart:typed_data';

import 'package:ababilx/core/app_version.dart';
import 'package:ababilx/features/app-update/app_update_check.dart';
import 'package:ababilx/features/app-update/app_update_info.dart';
import 'package:ababilx/features/app-update/app_update_snooze.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every request with [body] and records what was asked.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);

  final int status;
  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_StubAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;

void main() {
  group('AppUpdateInfo.fromJson', () {
    test('reads a required update', () {
      final info = AppUpdateInfo.fromJson({
        'latest_version': '5.3.0',
        'latest_build': 31,
        'update_available': true,
        'update_required': true,
        'whats_new': ' Faster calls \n',
        'store_url': 'https://play.google.com/store/apps/details?id=x',
      });
      expect(info.updateRequired, isTrue);
      expect(info.latestBuild, 31);
      expect(info.whatsNew, 'Faster calls');
    });

    test('required without anything newer never blocks', () {
      final info = AppUpdateInfo.fromJson({
        'update_available': false,
        'update_required': true,
      });
      expect(info.updateRequired, isFalse);
    });

    test('malformed reads as no update', () {
      final info = AppUpdateInfo.fromJson({'update_available': 'yes'});
      expect(info.updateAvailable, isFalse);
      expect(info.updateRequired, isFalse);
      expect(info.latestVersion, '');
    });
  });

  group('fetchAppUpdate', () {
    test('sends platform and the compiled-in build', () async {
      final adapter = _StubAdapter(200, {
        'success': true,
        'data': {'update_available': true, 'latest_build': 99},
      });
      final info = await fetchAppUpdate(
        dio: _dio(adapter),
        platform: 'android',
      );
      expect(info?.latestBuild, 99);
      expect(adapter.last?.path, '/v1/api/app/version');
      expect(adapter.last?.queryParameters, {
        'platform': 'android',
        'build': appBuildNumber,
      });
    });

    test('a server error is null, never an exception', () async {
      final adapter = _StubAdapter(500, {'success': false});
      expect(
        await fetchAppUpdate(dio: _dio(adapter), platform: 'android'),
        isNull,
      );
    });
  });

  group('AppUpdateSnooze', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Later hides that build only', () async {
      expect(await AppUpdateSnooze.isSnoozed(31), isFalse);
      await AppUpdateSnooze.snooze(31);
      expect(await AppUpdateSnooze.isSnoozed(31), isTrue);
      expect(await AppUpdateSnooze.isSnoozed(32), isFalse);
    });

    test('expires after the window', () async {
      final old = DateTime.now()
          .subtract(AppUpdateSnooze.window + const Duration(minutes: 1))
          .millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'app_update_snoozed_v1': '31:$old',
      });
      expect(await AppUpdateSnooze.isSnoozed(31), isFalse);
    });
  });
}
