import 'dart:async';

import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/network/ws_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/data/models/voice_call_session.dart';
import 'package:ababilx/features/calls/data/voice_call_api.dart';
import 'package:ababilx/features/calls/data/voice_call_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// An incoming call for the account `me`, as the server row would read.
VoiceCall testCall(String id, {String status = 'ringing'}) => VoiceCall(
  id: id,
  teamId: '',
  conversationId: 'chat-$id',
  callerId: 'peer',
  calleeId: 'me',
  status: status,
  callerName: 'Peer',
  calleeName: 'Me',
  expiresAt: DateTime.now().add(const Duration(minutes: 1)),
  createdAt: DateTime.now(),
);

VoiceCallSession testSession(
  String id, {
  String status = 'ringing',
  bool canControl = true,
}) => VoiceCallSession(
  call: testCall(id, status: status),
  iceServers: const [],
  canControl: canControl,
);

/// The same call as a socket event carries it.
Map<String, dynamic> callJson(String id, {String status = 'ringing'}) => {
  'id': id,
  'conversation_id': 'chat-$id',
  'caller_id': 'peer',
  'callee_id': 'me',
  'status': status,
  'caller_name': 'Peer',
  'callee_name': 'Me',
  'expires_at': DateTime.now()
      .add(const Duration(minutes: 1))
      .toUtc()
      .toIso8601String(),
  'created_at': DateTime.now().toUtc().toIso8601String(),
};

DioException httpError(int status, {String? apiError}) => DioException(
  requestOptions: RequestOptions(path: '/calls'),
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/calls'),
    statusCode: status,
    data: apiError == null ? null : {'error': apiError},
  ),
);

DioException offline() => DioException(
  requestOptions: RequestOptions(path: '/calls'),
  type: DioExceptionType.connectionError,
);

/// A server whose every answer the test decides.
class FakeCalls extends VoiceCallRepository {
  FakeCalls()
    : super(
        VoiceCallApi(ApiClient(const SecureStorage(FlutterSecureStorage()))),
      );

  /// What a GET answers, by call id.
  final rows = <String, VoiceCallSession>{};

  /// Errors the next GETs for a call throw, in order.
  final getErrors = <String, List<Object>>{};

  /// Errors the next `action:id` requests throw, in order.
  final actionErrors = <String, List<Object>>{};

  /// `action:id` requests held open until the test completes them.
  final held = <String, Completer<VoiceCallSession>>{};

  /// GETs held open until the test completes them, by call id.
  final heldLookups = <String, Completer<VoiceCallSession>>{};

  final lookups = <String>[];
  final actions = <String>[];

  @override
  Future<VoiceCallSession> get(String callId) async {
    lookups.add(callId);
    final errors = getErrors[callId];
    if (errors != null && errors.isNotEmpty) throw errors.removeAt(0);
    final gate = heldLookups[callId];
    if (gate != null) return gate.future;
    return rows[callId] ?? testSession(callId);
  }

  @override
  Future<VoiceCallSession> action(
    String id,
    String action, {
    String? reason,
  }) async {
    final key = '$action:$id';
    actions.add(key);
    final errors = actionErrors[key];
    if (errors != null && errors.isNotEmpty) throw errors.removeAt(0);
    final gate = held[key];
    if (gate != null) return gate.future;
    if (action == 'heartbeat') {
      return rows[id] ?? testSession(id, status: 'accepted');
    }
    final next = testSession(
      id,
      status: switch (action) {
        'accept' => 'accepted',
        'decline' => 'declined',
        'fail' => 'failed',
        _ => 'ended',
      },
    );
    rows[id] = next;
    return next;
  }
}

/// A socket the test feeds by hand.
class FakeWs extends WsClient {
  FakeWs() : super(const SecureStorage(FlutterSecureStorage()));

  final incoming = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get events => incoming.stream;

  @override
  Future<void> connect() async {}
}
