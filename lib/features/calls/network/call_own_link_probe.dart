import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import 'call_network_quality.dart';

/// Times a tiny request to the server every few seconds while a call rings,
/// and keeps [callOwnLinkQuality] up to date with the answer.
///
/// Counted, because the ringing screen and the call screen can both be
/// mounted for a moment as one hands over to the other: the probe runs while
/// anyone holds it and stops with the last release.
class CallOwnLinkProbe {
  CallOwnLinkProbe._();

  /// Off under `flutter test`, where a repeating request would outlive the
  /// widget test that mounted a call screen.
  static bool enabled = !Platform.environment.containsKey('FLUTTER_TEST');

  static const _every = Duration(seconds: 3);
  static const _limit = Duration(seconds: 4);

  static int _holders = 0;
  static int _run = 0;

  static void hold() {
    if (++_holders == 1 && enabled) unawaited(_loop(++_run));
  }

  static void release() {
    if (_holders == 0) return;
    if (--_holders > 0) return;
    _run++;
    callOwnLinkQuality.value = CallNetworkLevel.unknown;
  }

  static Future<void> _loop(int run) async {
    // No interceptors: no token, no retry, no sign-out on an odd answer.
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: _limit,
        receiveTimeout: _limit,
        validateStatus: (_) => true,
      ),
    );
    final trend = CallNetworkTrend();
    try {
      // The first request also opens the connection (DNS, TLS); only a
      // failure there says anything about the link.
      final opening = await _roundTrip(dio);
      if (run != _run) return;
      if (opening == null) {
        callOwnLinkQuality.value = trend.addLevel(CallNetworkLevel.poor);
      }
      while (run == _run) {
        final level = rateOwnLink(await _roundTrip(dio));
        if (run != _run) return;
        callOwnLinkQuality.value = trend.addLevel(level);
        await Future<void>.delayed(_every);
      }
    } finally {
      dio.close(force: true);
    }
  }

  static Future<int?> _roundTrip(Dio dio) async {
    final clock = Stopwatch()..start();
    try {
      await dio.get<void>('/');
      return clock.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }
}
