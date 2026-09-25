import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/app_version.dart';
import '../../core/constants/api_constants.dart';
import 'app_update_info.dart';

/// Asks the server whether this build is current.
///
/// A bare Dio on purpose: the route is public, and the app's [ApiClient]
/// would attach a token and treat a 401 as a sign-out — neither belongs on a
/// check that also runs on the login screen. Returns null on any failure;
/// an unreachable server must never block the app.
Future<AppUpdateInfo?> fetchAppUpdate({Dio? dio, String? platform}) async {
  platform ??= Platform.isAndroid
      ? 'android'
      : Platform.isIOS
      ? 'ios'
      : null;
  if (platform == null) return null;
  final client =
      dio ??
      Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
  try {
    final res = await client.get<Map<String, dynamic>>(
      ApiConstants.appVersion,
      queryParameters: {'platform': platform, 'build': appBuildNumber},
    );
    final data = res.data?['data'];
    if (data is! Map<String, dynamic>) return null;
    return AppUpdateInfo.fromJson(data);
  } catch (e) {
    debugPrint('[app-update] check failed: $e');
    return null;
  } finally {
    if (dio == null) client.close();
  }
}
