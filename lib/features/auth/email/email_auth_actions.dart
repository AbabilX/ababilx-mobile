import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/friendly_error.dart';
import '../data/auth_session.dart';
import '../providers/auth_provider.dart';
import '../widgets/account_switch_prompt.dart';
import 'email_auth_repository.dart';

/// The server's refusal in the app's language when there is a translation
/// for its code, the server's own sentence otherwise, and the offline copy
/// for a dead connection.
String emailAuthErrorText(BuildContext context, WidgetRef ref, Object error) {
  String t(String key) => AppTranslations.translate(context, ref, key);
  if (error is EmailAuthException) {
    final key = 'email_err_${error.code}';
    final local = t(key);
    if (local != key) return local;
    return error.message.isNotEmpty ? error.message : t('email_auth_failed');
  }
  if (isOfflineError(error)) return friendlyErrorMessage(error);
  return t('email_auth_failed');
}

/// Hands a server-accepted session to AuthNotifier, asking first if it would
/// replace another account's data on this phone. The router takes it from
/// there; a failure is rethrown for the screen to show.
Future<void> adoptEmailSession(
  BuildContext context,
  WidgetRef ref,
  PreparedAuthSession session,
) async {
  final outcome = await ref
      .read(authProvider.notifier)
      .signInWithSession(session);
  if (outcome is SignInFailed) throw outcome.error;
  if (!context.mounted) return;
  await settleAccountSwitch(context, ref, outcome);
}

bool looksLikeEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
