import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'history_transfer_crypto.dart';
import 'history_transfer_envelope_codec.dart';
import 'history_transfer_provider.dart';
import 'v2/v2_crypto.dart';
import 'live/live_session.dart';
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
    bool live = false,
  }) async {
    if (version > HistoryTransferV2Crypto.version || version < 2) return null;
    final api = ref.read(historyTransferApiProvider);
    final v2Api = ref.read(historyTransferV2ApiProvider);
    final notifier = ref.read(historyTransferProvider.notifier);
    final destinationJwk = HistoryTransferEnvelopeCodec.decode(historyKeyParam);

    final deadline = DateTime.now().add(_wait);
    var allowLive = live;
    while (true) {
      var triedLive = false;
      try {
        final request = await api.inspectByLogin(loginToken);
        final capabilities = await v2Api.capabilities();
        validateHistoryTransferV2Capabilities(capabilities);
        // Live only when both the new device (hl=1) and the server (0175)
        // speak it; otherwise the v2 relay, exactly as before.
        final goLive = allowLive && liveSupported(capabilities);
        triedLive = goLive;
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
          live: goLive,
        );
        if (goLive) {
          // Nothing is uploaded: the computer asks for what it needs.
          await ref
              .read(historyLiveProvider.notifier)
              .adopt(linkId: id, key: key, device: request.deviceName);
        } else {
          unawaited(notifier.sendV2(transferId: id, transferKey: key));
        }
        return request.deviceName.isNotEmpty
            ? request.deviceName
            : 'that device';
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        if (triedLive && status != null && status != 404) {
          // The server would not make a live link of it (a sign-in with no
          // session to bind, say): send the old way rather than nothing.
          debugPrint('[one-scan] live refused ($status), using the relay');
          allowLive = false;
          continue;
        }
        final notReady = status == 404;
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

/// The server relays live history links (`live_versions` lists 1).
bool liveSupported(Map<String, dynamic> capabilities) =>
    (capabilities['live_versions'] as List? ?? const []).contains(1);
