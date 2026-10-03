import 'package:flutter/material.dart';

import '../../../shared/widgets/app_toast.dart';
import '../services/share_sender.dart';
import 'share_error_message.dart';

/// Tells the user exactly what happened to a share.
///
/// Split out because there are three separate truths to report and they are
/// not exclusive: nothing sent, some recipients missed, some files dropped.
/// Collapsing them into one "Sent!" is how a partial send goes unnoticed.
///
/// **Every way a share can fail ends here.** Four of them used to be a bare
/// `return` — an empty payload, nothing resolved, and a throw on the way to
/// sending, which escaped into the picker's own `catch (_)`. The spinner
/// stopped, the screen stayed, and nothing was said, which reads as Send being
/// broken.
class ShareResultReport {
  const ShareResultReport._();

  /// Send with no files and no text behind it.
  static void nothingToSend(BuildContext context) =>
      _show(context, 'Nothing to share yet. Add a message first.');

  /// Picked destinations that resolved to no conversation at all.
  static void noRecipients(BuildContext context) =>
      _show(context, 'Pick at least one chat to share with.');

  /// A throw on the way to sending. Opening a DM for somebody who has no chat
  /// with you yet is the common one, and it happens before a single byte is
  /// uploaded.
  static void error(BuildContext context, Object error) =>
      _show(context, shareErrorMessage(error));

  /// A send that finished after its screen was left: reported on the root
  /// overlay taken before leaving. Says nothing when everything arrived.
  static void settled(
    OverlayState? overlay,
    ShareSendResult result,
    int targetCount,
  ) {
    void say(String message) => showAppToastIn(overlay, message, isError: true);
    if (result.noneSent) return say('Could not send. Try again.');
    if (result.skippedFiles > 0) {
      final n = result.skippedFiles;
      say('$n file${n == 1 ? '' : 's'} could not be attached.');
    }
    if (!result.allSent) {
      say('Sent to ${result.sent} of $targetCount conversations.');
    }
  }

  /// A toast, never a SnackBar: this screen's send bar sits at the bottom, and
  /// the success path reports *after* routing away — a SnackBar goes down with
  /// the route that raised it, the toast lives in the root overlay.
  static void _show(BuildContext context, String message) =>
      showAppToast(context, message, isError: true);
}
