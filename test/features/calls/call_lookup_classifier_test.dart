import 'dart:async';

import 'package:ababilx/features/calls/call_lookup_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/call_fakes.dart';

/// Which failures say something about the call, and which only about the
/// request. The recovery paths end a ringing surface on the first kind only.
void main() {
  group('what a failed lookup says about the call', () {
    DioException transport(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/calls'),
      type: type,
    );

    test('no answer at all is transient', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
        DioExceptionType.unknown,
      ]) {
        expect(
          classifyCallLookupFailure(transport(type)),
          CallLookupFailure.transient,
          reason: '$type',
        );
      }
      expect(
        classifyCallLookupFailure(TimeoutException('slow')),
        CallLookupFailure.transient,
      );
    });

    test('a server that could not answer is transient', () {
      for (final status in [401, 408, 429, 500, 502, 503, 504]) {
        expect(
          classifyCallLookupFailure(httpError(status)),
          CallLookupFailure.transient,
          reason: '$status',
        );
      }
    });

    test('only "no such call" ends it for good', () {
      expect(classifyCallLookupFailure(httpError(404)), CallLookupFailure.gone);
      expect(
        classifyCallLookupFailure(
          httpError(400, apiError: 'voice_call_not_found'),
        ),
        CallLookupFailure.gone,
      );
    });

    test('a refusal, a conflict and an unreadable body are told apart', () {
      expect(
        classifyCallLookupFailure(httpError(403)),
        CallLookupFailure.rejected,
      );
      expect(
        classifyCallLookupFailure(httpError(409)),
        CallLookupFailure.conflict,
      );
      expect(
        classifyCallLookupFailure(const FormatException('bad json')),
        CallLookupFailure.malformed,
      );
    });
  });
}
