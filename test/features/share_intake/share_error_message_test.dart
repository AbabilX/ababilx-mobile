import 'package:ababilx/features/share_intake/share-target/share_error_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dio({DioExceptionType? type, Object? data}) {
  final options = RequestOptions(path: '/api/chat/dm');
  return DioException(
    requestOptions: options,
    type: type ?? DioExceptionType.badResponse,
    response: data == null
        ? null
        : Response<dynamic>(
            requestOptions: options,
            statusCode: 403,
            data: data,
          ),
  );
}

void main() {
  group('shareErrorMessage', () {
    test('a vault StateError is shown as written', () {
      expect(
        shareErrorMessage(
          StateError('Jibon must set up secure messages first.'),
        ),
        'Jibon must set up secure messages first.',
      );
    });

    test("the server's own sentence wins over the generic one", () {
      expect(
        shareErrorMessage(
          _dio(
            data: {
              'error': 'connection_required',
              'message': 'Send them a request first.',
            },
          ),
        ),
        'Send them a request first.',
      );
    });

    test('the machine-readable code is never shown', () {
      final message = shareErrorMessage(
        _dio(data: {'error': 'connection_required'}),
      );
      expect(message, isNot(contains('connection_required')));
      expect(message, 'Could not send. Try again.');
    });

    test('offline says so, because it is the one thing the user can fix', () {
      expect(
        shareErrorMessage(_dio(type: DioExceptionType.connectionError)),
        contains('No internet connection'),
      );
    });

    test('anything else falls back, and never dumps the exception', () {
      expect(
        shareErrorMessage(Exception('SocketException: host lookup 10.0.0.1')),
        'Could not send. Try again.',
      );
    });

    test('an empty StateError does not surface as a blank toast', () {
      expect(
        shareErrorMessage(StateError('   ')),
        'Could not send. Try again.',
      );
    });
  });
}
