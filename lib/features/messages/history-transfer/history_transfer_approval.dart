import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_toast.dart';
import '../message_e2ee/message_vault.dart';
import 'history_transfer_crypto.dart';
import 'history_transfer_payload.dart';
import 'history_transfer_provider.dart';
import 'history_transfer_sheet.dart';
import 'history_transfer_verification.dart';

/// Approving a scanned device's request for this phone's history.
///
/// One approval covers the whole handover — the destination is already signed
/// in and already holds the message key by the time it asks — and the sheet
/// says what is about to move before anything does. Declining calls deny, so
/// the waiting device stops immediately instead of sitting on a dead code.
class HistoryTransferApproval {
  HistoryTransferApproval._();

  static Future<void> start(
    BuildContext context,
    WidgetRef ref,
    String payload,
  ) async {
    final scanned = parseHistoryTransferPayload(payload);
    if (scanned == null) {
      showAppToast(context, 'That code is not a history transfer.');
      return;
    }
    if (scanned.version > HistoryTransferCrypto.formatVersion) {
      // Refused up front rather than after uploading chunks the destination
      // could not open — a failure with nothing to show for the wait.
      showAppToast(context, 'Update AbabilX on this phone to send history.');
      return;
    }
    // History is sealed with the account's own messages behind it: a phone
    // that cannot read its own messages has nothing to hand over.
    final vault = ref.read(messageVaultProvider);
    if (!vault.isUnlocked && !await vault.restoreTrustedIdentity()) {
      if (context.mounted) {
        showAppToast(context, 'Open your messages on this device first.');
      }
      return;
    }

    final api = ref.read(historyTransferApiProvider);
    HistoryTransferRequestView view;
    try {
      final request = await api.inspect(scanned.token);
      view = HistoryTransferRequestView(
        deviceName: request.deviceName,
        client: request.client,
        code: await historyTransferVerificationCode(scanned.destinationJwk),
      );
    } catch (error) {
      if (context.mounted) showAppToast(context, _failureMessage(error));
      return;
    }
    if (!context.mounted) return;

    final approved = await HistoryTransferSheet.confirm(context, view);
    if (!context.mounted) return;
    if (approved != true) {
      try {
        await api.deny(scanned.token);
      } catch (_) {}
      return;
    }

    try {
      final key = HistoryTransferCrypto.newTransferKey();
      final id = await api.approve(
        token: scanned.token,
        deviceName: view.deviceName,
        envelope: await HistoryTransferCrypto.sealTransferKey(
          transferKey: key,
          destinationJwk: scanned.destinationJwk,
        ),
        destinationJwk: scanned.destinationJwk,
      );
      // Not awaited: the export runs for as long as the history is large, and
      // the user approved a transfer, not a progress bar. Its state lives in
      // the provider, which the sheet and any later screen can read.
      unawaited(
        ref
            .read(historyTransferProvider.notifier)
            .send(transferId: id, transferKey: key, deviceId: view.deviceName),
      );
      if (context.mounted) {
        showAppToast(context, 'Sending your history to ${view.label}.');
      }
    } catch (error) {
      if (context.mounted) showAppToast(context, _failureMessage(error));
    }
  }

  /// 410 covers a stale code, a consumed one AND one belonging to another
  /// account — deliberately, so a stranger's token reveals nothing. The
  /// message says so rather than picking one and sounding certain.
  static String _failureMessage(Object error) {
    final status = error is DioException ? error.response?.statusCode : null;
    final code = error is DioException
        ? (error.response?.data is Map
              ? (error.response!.data as Map)['error']?.toString() ?? ''
              : '')
        : '';
    if (code == 'history_transfer_active') {
      return 'A history transfer is already running. Cancel it first.';
    }
    if (code == 'destination_key_mismatch') {
      return 'That code does not match the device that made it. Scan again.';
    }
    if (code == 'session_binding_required' || status == 401 || status == 403) {
      return 'Sign in again on this phone, then scan once more.';
    }
    if (status == 410) {
      return 'That code has expired, or it belongs to a different account.';
    }
    if (status == 503) {
      return 'History transfer is not available on this server yet.';
    }
    if (status == null) {
      return 'Could not reach the server. Check your connection.';
    }
    return 'Could not read that code (error $status).';
  }
}

/// What the approval sheet needs to show. The verification code is derived on
/// this phone from the scanned key, never taken from the server's answer.
class HistoryTransferRequestView {
  const HistoryTransferRequestView({
    required this.deviceName,
    required this.client,
    required this.code,
  });

  final String deviceName;
  final String client;
  final String code;

  String get label => deviceName.isNotEmpty
      ? deviceName
      : (client.isNotEmpty ? client : 'that device');
}
