import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_model.dart';
import '../models/file_dto.dart';
import '../models/session_state.dart';
import '../services/local_server_service.dart';
import '../services/transfer_client_service.dart';
import 'local_share_providers.dart';
import 'transfer_history_provider.dart';

/// Provider for managing active local share transfer sessions.
final localShareSessionsProvider =
    StateNotifierProvider<
      LocalShareSessionsNotifier,
      Map<String, ShareSessionState>
    >((ref) {
      return LocalShareSessionsNotifier(ref);
    });

const _terminalSessionStatuses = {
  TransferSessionStatus.finished,
  TransferSessionStatus.error,
  TransferSessionStatus.canceled,
  TransferSessionStatus.declined,
};

class LocalShareSessionsNotifier
    extends StateNotifier<Map<String, ShareSessionState>> {
  final Ref _ref;
  final Set<String> _recordedSessionIds = {};

  LocalShareSessionsNotifier(this._ref) : super({}) {
    // Listen for incoming server sessions
    _serverService.onSessionUpdated = (session) {
      updateSession(session);
    };
  }

  LocalServerService get _serverService =>
      _ref.read(localServerServiceProvider);
  LocalTransferClientService get _clientService =>
      _ref.read(localTransferClientServiceProvider);
  LocalDevice get _currentDevice => _ref.read(currentLocalDeviceProvider);

  /// Starts local server. Publishes the actual bound port (may fall back
  /// off the default if it was taken) so discovery advertises a port peers
  /// can really reach.
  Future<int> startServer() async {
    final port = await _serverService.startServer(
      currentDevice: _currentDevice,
    );
    _ref.read(serverPortProvider.notifier).state = port;
    return port;
  }

  /// Sends files to a target peer device.
  Future<ShareSessionState> sendFiles({
    required LocalDevice targetDevice,
    required List<LocalFileDto> files,
  }) async {
    return await _clientService.sendFiles(
      targetDevice: targetDevice,
      currentDevice: _currentDevice,
      files: files,
      onProgress: (sessionState) {
        updateSession(sessionState);
      },
    );
  }

  /// Cancels a session.
  Future<void> cancelSession(String sessionId) async {
    final session = state[sessionId];
    if (session != null && session.isOutgoing) {
      await _clientService.cancelSession(sessionId, session.targetDevice);
    }
  }

  void updateSession(ShareSessionState session) {
    state = {...state, session.sessionId: session};

    if (_terminalSessionStatuses.contains(session.status) &&
        _recordedSessionIds.add(session.sessionId)) {
      unawaited(
        _ref.read(transferHistoryProvider.notifier).recordSession(session),
      );
    }
  }
}
