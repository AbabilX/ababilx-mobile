import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Compatibility entry for callers outside Settings. No unverified reveal.
class RecoveryCodeDialog {
  static Future<void> show(BuildContext context) async {
    await context.push('/settings/chat-backup/recovery-codes');
  }
}
