import 'package:ababilx/features/spaces/data/space_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _status(int code, [Object? body]) {
  final req = RequestOptions(path: '/v1/spaces');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: req, statusCode: code, data: body),
  );
}

void main() {
  test('offline kinds', () {
    for (final t in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ]) {
      expect(
        classifySpaceError(
          DioException(requestOptions: RequestOptions(), type: t),
        ),
        SpaceFailure.offline,
      );
    }
  });

  test('server side trouble reads as unavailable', () {
    for (final code in [404, 500, 502, 503, 504]) {
      expect(
        classifySpaceError(_status(code)),
        SpaceFailure.unavailable,
        reason: '$code',
      );
    }
    expect(
      classifySpaceError(const SpaceUnavailable()),
      SpaceFailure.unavailable,
    );
  });

  test('auth and rate limits', () {
    expect(classifySpaceError(_status(401)), SpaceFailure.signedOut);
    expect(classifySpaceError(_status(403)), SpaceFailure.forbidden);
    expect(classifySpaceError(_status(429)), SpaceFailure.busy);
  });

  test('offline copy does not claim the phone is offline', () {
    // A dead Space host looks like no network; the words must fit both.
    expect(
      spaceFailureCopy(SpaceFailure.offline).title,
      isNot(contains('No internet')),
    );
  });

  test('anything else is unknown, never a raw dump', () {
    expect(classifySpaceError(StateError('x')), SpaceFailure.unknown);
    expect(
      classifySpaceError(const FormatException('bad json')),
      SpaceFailure.unknown,
    );
    for (final f in SpaceFailure.values) {
      expect(spaceFailureCopy(f).title, isNotEmpty);
      expect(
        spaceFailureCopy(f).title.toLowerCase(),
        isNot(contains('exception')),
      );
    }
  });
}
