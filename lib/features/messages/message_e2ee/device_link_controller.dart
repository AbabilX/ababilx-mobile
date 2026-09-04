import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import 'message_vault.dart';
import 'p256_ecdh.dart';

enum DeviceLinkStatus { loading, waiting, linked, denied, expired, error }

class DeviceLinkState {
  const DeviceLinkState({
    this.status = DeviceLinkStatus.loading,
    this.payload = '',
    this.verificationCode = '',
    this.error = '',
  });

  final DeviceLinkStatus status;

  /// The whole QR payload: scheme, routing token, and this device's ephemeral
  /// public key.
  final String payload;
  final String verificationCode;
  final String error;
}

/// Drives one device-link handshake from the new device's side.
///
/// The ephemeral private key lives in this object and is never written down: if
/// the screen is left the link simply has to be started again, which is cheaper
/// than leaving a key that can open an identity lying on disk. Restarting mints
/// a fresh pair, so an abandoned QR goes dead.
class DeviceLinkController extends StateNotifier<DeviceLinkState> {
  DeviceLinkController(this._ref) : super(const DeviceLinkState()) {
    start();
  }

  final Ref _ref;
  P256KeyPair? _ephemeral;
  Timer? _poll;
  bool _disposed = false;

  Future<void> start() async {
    _poll?.cancel();
    state = const DeviceLinkState();
    final vault = _ref.read(messageVaultProvider);
    try {
      final ephemeral = vault.newLinkEphemeral();
      _ephemeral = ephemeral;
      final session = await _ref
          .read(chatRepositoryProvider)
          .createE2eeLink(_deviceName());
      if (_disposed) return;
      final token = session['token'] as String;
      final payload =
          '${session['scheme']}$token&k=${vault.encodeLinkPublicKey(ephemeral)}';
      state = DeviceLinkState(
        status: DeviceLinkStatus.waiting,
        payload: payload,
        verificationCode: await vault.linkVerificationCode(
          vault.decodeLinkPublicKey(vault.encodeLinkPublicKey(ephemeral)),
        ),
      );
      final interval = (session['poll_interval'] as num?)?.toInt() ?? 2;
      final expiresAt =
          DateTime.tryParse(session['expires_at'] as String? ?? '') ??
          DateTime.now().add(const Duration(minutes: 3));
      _poll = Timer.periodic(
        Duration(seconds: interval),
        (_) => _tick(token, expiresAt),
      );
    } catch (error) {
      if (_disposed) return;
      state = DeviceLinkState(
        status: DeviceLinkStatus.error,
        error: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<void> _tick(String token, DateTime expiresAt) async {
    if (DateTime.now().isAfter(expiresAt)) return _stop(DeviceLinkStatus.expired);
    try {
      final result = await _ref.read(chatRepositoryProvider).pollE2eeLink(token);
      if (_disposed) return;
      switch (result['status']) {
        case 'pending':
          return;
        case 'denied':
          return _stop(DeviceLinkStatus.denied);
        case 'approved':
          final envelope = result['identity_envelope'];
          final ephemeral = _ephemeral;
          if (envelope is! Map || ephemeral == null) {
            return _stop(DeviceLinkStatus.expired);
          }
          _poll?.cancel();
          await _ref
              .read(messageVaultProvider)
              .adoptLinkedIdentity(
                Map<String, dynamic>.from(envelope),
                ephemeral,
              );
          if (_disposed) return;
          state = DeviceLinkState(
            status: DeviceLinkStatus.linked,
            payload: state.payload,
            verificationCode: state.verificationCode,
          );
        default:
          return _stop(DeviceLinkStatus.expired);
      }
    } catch (error) {
      if (_disposed) return;
      _poll?.cancel();
      state = DeviceLinkState(
        status: DeviceLinkStatus.error,
        error: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  void _stop(DeviceLinkStatus status) {
    _poll?.cancel();
    if (!_disposed) {
      state = DeviceLinkState(
        status: status,
        payload: state.payload,
        verificationCode: state.verificationCode,
      );
    }
  }

  String _deviceName() =>
      Platform.isAndroid ? 'AbabilX on Android' : 'AbabilX on iPhone';

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _ephemeral = null;
    super.dispose();
  }
}

final deviceLinkControllerProvider =
    StateNotifierProvider.autoDispose<DeviceLinkController, DeviceLinkState>(
      DeviceLinkController.new,
    );
