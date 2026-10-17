import 'package:ababilx/features/auth/data/linked_device_limit.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _refusal(int status, Object? body) {
  final options = RequestOptions(path: '/api/auth/qr/approve');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: body),
  );
}

void main() {
  test('reads the server 409 with its device list', () {
    final limit = LinkedDeviceLimit.from(
      _refusal(409, {
        'success': false,
        'error': 'linked_device_limit',
        'data': {
          'limit': 5,
          'devices': [
            {
              'device_id': 'd1',
              'platform': 'desktop',
              'session_id': 's1',
              'label': 'Office iMac',
              'linked_at': '2026-10-01T10:00:00Z',
              'last_seen_at': '2026-10-17T10:00:00Z',
            },
            {'device_id': 'd2', 'platform': 'web'},
          ],
        },
      }),
    );
    expect(limit, isNotNull);
    expect(limit!.limit, 5);
    expect(limit.devices.map((d) => d.sessionId), ['s1', '']);
    expect(limit.devices.first.label, 'Office iMac');
    expect(limit.devices.last.platform, 'web');
  });

  test('anything else is not the limit', () {
    expect(LinkedDeviceLimit.from(StateError('x')), isNull);
    expect(LinkedDeviceLimit.from(_refusal(409, {'error': 'other'})), isNull);
    expect(
      LinkedDeviceLimit.from(_refusal(400, {'error': 'linked_device_limit'})),
      isNull,
    );
    expect(LinkedDeviceLimit.from(_refusal(409, 'not json')), isNull);
  });

  test('a body with no data still names the default limit', () {
    final limit = LinkedDeviceLimit.from(
      _refusal(409, {'error': 'linked_device_limit'}),
    );
    expect(limit!.limit, 5);
    expect(limit.devices, isEmpty);
  });
}
