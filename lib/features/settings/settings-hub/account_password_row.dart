import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../profile/data/profile_repository.dart';
import 'settings_row.dart';

/// Password for an account with an email (a Google account adds its first
/// one here). An account with none (Start New Chat) gets "Secure your
/// account" instead: email + password, so a lost phone is not a lost account.
class AccountPasswordRow extends ConsumerWidget {
  const AccountPasswordRow({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final unsecured = user.email.isEmpty;
    return SettingsRow(
      icon: unsecured
          ? HugeIcons.strokeRoundedShieldUser
          : HugeIcons.strokeRoundedSquareLock01,
      title: t(unsecured ? 'account_setup_title' : 'settings_password'),
      subtitle: t(unsecured ? 'account_setup_sub' : 'settings_password_sub'),
      onTap: () => context.push(
        unsecured ? '/settings/account-setup' : '/settings/password',
      ),
    );
  }
}
