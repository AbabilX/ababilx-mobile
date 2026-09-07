import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/root_back.dart';
import '../../profile/providers/profile_provider.dart';
import '../avatar/avatar_flow.dart';
import '../settings-hub/settings_bio_row.dart';
import '../settings-hub/settings_sections.dart';

/// Settings hub, reached from the 3-dot in the chat list header.
///
/// Everything that used to be scattered across the You sheet and the Profile
/// screen has one address now; Profile stays as the account detail page the
/// "Account" row opens, rather than doubling as the settings surface.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    String t(String key) => AppTranslations.translate(context, ref, key);

    return Scaffold(
      appBar: AppBar(
        // RootBackScope wraps the app with canPop:false, so an implicit back
        // arrow is inert — every pushed screen here wires its own.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGoHome(context),
        ),
        title: Text(t('settings_title')),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(t('settings_load_error'))),
        data: (user) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SettingsBioRow(
              user: user,
              onQrTap: () => context.push('/settings/qr'),
              onEditName: () => context.push('/settings/name'),
              onEditAvatar: () => startAvatarFlow(context, ref),
            ),
            const Divider(height: 8),
            SettingsSections(user: user),
          ],
        ),
      ),
    );
  }
}
