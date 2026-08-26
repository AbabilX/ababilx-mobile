import 'package:flutter/material.dart';

import '../services/share_sender.dart';

/// Tells the user exactly what happened to a share.
///
/// Split out because there are three separate truths to report and they are
/// not exclusive: nothing sent, some recipients missed, some files dropped.
/// Collapsing them into one "Sent!" is how a partial send goes unnoticed.
class ShareResultReport {
  const ShareResultReport._();

  static void failure(BuildContext context) {
    _show(context, 'Could not send. Try again.');
  }

  /// Anything the user needs to know after a send that did reach someone.
  static void partial(
    BuildContext context,
    ShareSendResult result,
    int targetCount,
  ) {
    if (result.skippedFiles > 0) {
      final n = result.skippedFiles;
      _show(context, '$n file${n == 1 ? '' : 's'} could not be attached.');
    }
    if (!result.allSent) {
      _show(
        context,
        'Sent to ${result.sent} of $targetCount conversations.',
      );
    }
  }

  static void _show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
