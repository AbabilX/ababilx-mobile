import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../local_share/widgets/qr_scan_sheet.dart';
import '../../messages/chat-people/scanned_user_sheet.dart';
import '../../messages/chat-people/user_qr_payload.dart';
import '../../messages/group-link/group_link_join_sheet.dart';
import '../../messages/group-link/group_link_payload.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/history-transfer/history_transfer_approval.dart';
import '../../messages/history-transfer/history_transfer_one_scan.dart';
import '../../messages/history-transfer/history_transfer_payload.dart';
import '../../messages/message_e2ee/device_link_approval.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../transfer-chats/ui/transfer_send_sheet.dart';
import '../../transfer-chats/wire/transfer_chats_payload.dart';
import '../data/one_scan_payload.dart';
import '../data/qr_login_repository.dart';
import 'linked_limit_sheet.dart';
import 'qr_login_confirm_sheet.dart';

/// Scan a QR from another device and act on it, told apart by the
/// `ababilx://` host: a **sign-in** code hands that device a session; a
/// **device-link** code hands it this account's message key (the server has
/// no copy to give); a **history-transfer** code asks for the messages and
/// files this phone holds; a **transfer-chats** code is a new phone on this
/// Wi-Fi asking for everything (`features/transfer-chats/`); a **user** code
/// is somebody's handle, and opens a chat with them.
///
/// A current web/desktop sign-in code also carries the device's message and
/// history keys (`one_scan_payload.dart`): one scan, one dialog. Device codes
/// show what is approved first; declining calls the deny endpoint so the
/// waiting device stops at once. A user code approves nothing — a handle is
/// public, and its sheet is the confirmation.
class QrLoginFlow {
  QrLoginFlow._();

  static Future<void> start(BuildContext context, WidgetRef ref) async {
    // Home's floating pill is painted over this navigator: hide it, or a
    // sheet from the chat list sits underneath it (same as the You sheet).
    final hidden = ref.read(shellBottomBarHiddenProvider.notifier);
    hidden.state = true;
    try {
      await _dispatch(context, ref);
    } finally {
      hidden.state = false;
    }
  }

  static Future<void> _dispatch(BuildContext context, WidgetRef ref) async {
    final payload = await QrScanSheet.show(context);
    if (payload == null || !context.mounted) return;
    await _act(context, ref, payload);
  }

  /// [start] for a code already read elsewhere (Add friends scans inline).
  static Future<void> handle(
    BuildContext context,
    WidgetRef ref,
    String payload,
  ) async {
    final hidden = ref.read(shellBottomBarHiddenProvider.notifier);
    hidden.state = true;
    try {
      await _act(context, ref, payload);
    } finally {
      hidden.state = false;
    }
  }

  static Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    String payload,
  ) async {
    final repo = ref.read(qrLoginRepositoryProvider);

    if (isDeviceLinkPayload(payload)) {
      await DeviceLinkApproval.start(context, ref, payload);
      return;
    }
    if (isHistoryTransferPayload(payload)) {
      await HistoryTransferApproval.start(context, ref, payload);
      return;
    }
    if (isTransferChatsPayload(payload)) {
      await showTransferSendSheet(context, ref, payload);
      return;
    }
    final handle = usernameFromQrPayload(payload);
    if (handle != null) {
      await ScannedUserSheet.open(context, ref, handle);
      return;
    }
    final group = slugFromGroupLink(payload);
    if (group != null) {
      await GroupLinkJoinSheet.open(context, ref, group);
      return;
    }
    if (!repo.isLoginPayload(payload)) {
      _toast(context, ref, 'qr_login_invalid');
      return;
    }

    QrLoginRequest request;
    try {
      request = await repo.inspect(payload);
    } on QrLoginExpired {
      if (context.mounted) _toast(context, ref, 'qr_login_expired');
      return;
    } catch (_) {
      if (context.mounted) _toast(context, ref, 'qr_login_failed');
      return;
    }
    if (!context.mounted) return;

    // One scan: the code may also carry the new device's message key and
    // history key. Both need this phone's own identity; without it the
    // sign-in still goes through and the other device asks the usual way.
    final keys = parseOneScanKeys(payload);
    final vault = ref.read(messageVaultProvider);
    final canShare =
        keys.hasLinkKey &&
        (vault.isUnlocked || await vault.restoreTrustedIdentity());
    final linkJwk = canShare
        ? vault.decodeLinkPublicKey(keys.linkKeyParam!)
        : null;
    final code = linkJwk == null
        ? null
        : await vault.linkVerificationCode(linkJwk);
    if (!context.mounted) return;

    final approved = await showQrLoginConfirmSheet(
      context,
      ref,
      request: request,
      code: code,
    );
    if (!context.mounted) return;

    try {
      if (!approved) {
        await repo.deny(payload);
        return;
      }
      final envelope = linkJwk == null
          ? null
          : await vault.sealIdentityForDevice(linkJwk);
      if (!context.mounted) return;
      // Past the linked-device limit (server 0174) the user signs one out
      // and the same code is approved again; backing out ends it.
      final signedIn = await approveMakingRoom(
        context,
        ref,
        () => repo.approve(payload, identityEnvelope: envelope),
      );
      if (!signedIn) {
        await repo.deny(payload).catchError((_) {});
        return;
      }
      if (context.mounted) _toast(context, ref, 'qr_login_done');
    } on QrLoginExpired {
      if (context.mounted) _toast(context, ref, 'qr_login_expired');
      return;
    } catch (_) {
      if (context.mounted) _toast(context, ref, 'qr_login_failed');
      return;
    }

    // Chats go with the sign-in whenever the code carries a history key —
    // no switch to turn it off (user's call, 2026-10-18).
    if (canShare && keys.hasHistoryKey && context.mounted) {
      // Not awaited: the new device opens its transfer only once signed in,
      // and the scanner must not sit open (bottom bar hidden) while it does.
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      unawaited(
        HistoryTransferOneScan.sendAfterSignIn(
          ref,
          loginToken: signInTokenOf(payload),
          historyKeyParam: keys.historyKeyParam!,
          version: keys.historyVersion,
          allowLiveLink: keys.historyLive,
        ).then((sentTo) {
          if (sentTo != null) {
            showAppToastIn(overlay, 'Sending your chats to $sentTo.');
          }
        }),
      );
    }
  }

  static void _toast(BuildContext context, WidgetRef ref, String key) {
    showAppToast(context, AppTranslations.translate(context, ref, key));
  }
}
