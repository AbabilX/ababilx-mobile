import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'history_transfer_crypto.dart';
import 'history_transfer_envelope_codec.dart';
import 'history_transfer_provider.dart';
import 'v2/v2_crypto.dart';
import 'v2/v2_exporter.dart';

/// History half of a one-scan sign-in (2026-10-02).
///
/// The sign-in QR carried the new device's history key (`h`). That device can
/// only open its transfer once it is signed in, so this phone — which just
/// approved the sign-in — waits for it, finds it by the sign-in token, and
/// approves it exactly as a scanned history code would be approved: the key
/// sealed to is the one off the camera, and the server refuses a transfer
/// registered under any other. The user already said yes in the one dialog.
class HistoryTransferOneScan {
  HistoryTransferOneScan._();

  static const _wait = Duration(minutes: 2);
  static const _every = Duration(seconds: 2);

  /// Returns the device label on success, null when nothing was sent.
  static Future<String?> sendAfterSignIn(
    WidgetRef ref, {
    required String loginToken,
    required String historyKeyParam,
    required int version,
  }) async {
    if (version > HistoryTransferV2Crypto.version || version < 2) return null;
    final api = ref.read(historyTransferApiProvider);
    final v2Api = ref.read(historyTransferV2ApiProvider);
    final notifier = ref.read(historyTransferProvider.notifier);
    final destinationJwk = HistoryTransferEnvelopeCodec.decode(historyKeyParam);

    final deadline = DateTime.now().add(_wait);
    while (true) {
      try {
        final request = await api.inspectByLogin(loginToken);
        validateHistoryTransferV2Capabilities(await v2Api.capabilities());
        final key = HistoryTransferCrypto.newTransferKey();
        final id = await api.approve(
          token: '',
          loginToken: loginToken,
          deviceName: request.deviceName,
          envelope: await HistoryTransferV2Crypto.sealEnvelope(
            transferId: request.id,
            transferKey: key,
            destinationJwk: destinationJwk,
          ),
          destinationJwk: destinationJwk,
          destinationKeyParam: historyKeyParam,
        );
        unawaited(notifier.sendV2(transferId: id, transferKey: key));
        return request.deviceName.isNotEmpty
            ? request.deviceName
            : 'that device';
      } on DioException catch (error) {
        final notReady = error.response?.statusCode == 404;
        if (!notReady || DateTime.now().isAfter(deadline)) {
          debugPrint('[one-scan] history not sent: ${error.response?.data}');
          return null;
        }
      } catch (error) {
        debugPrint('[one-scan] history not sent: $error');
        return null;
      }
      await Future<void>.delayed(_every);
    }
  }
}
