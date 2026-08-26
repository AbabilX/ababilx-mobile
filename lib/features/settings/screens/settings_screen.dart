import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/root_back.dart';
import '../../auth/widgets/qr_login_flow.dart';
import '../../profile/providers/profile_provider.dart';
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

    return Scaffold(
      appBar: AppBar(
        // RootBackScope wraps the app with canPop:false, so an implicit back
        // arrow is inert — every pushed screen here wires its own.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGoHome(context),
        ),
        title: const Text('Settings'),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load settings')),
        data: (user) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SettingsBioRow(
              user: user,
              onQrTap: () => QrLoginFlow.start(context, ref),
            ),
            const Divider(height: 8),
            SettingsSections(user: user),
          ],
        ),
      ),
    );
  }
}
