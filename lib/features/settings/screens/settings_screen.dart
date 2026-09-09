import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/root_back.dart';
import '../../messages/chat-details/details_floating_chrome.dart';
import '../../messages/chat-details/group_banner_header.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_provider.dart';
import '../avatar/avatar_flow.dart';
import '../avatar/cover_flow.dart';
import '../settings-hub/settings_bio_row.dart';
import '../settings-hub/settings_sections.dart';

/// Settings hub, reached from the 3-dot in the chat list header.
///
/// The cover is the header background — same layout as a group or DM info
/// page — and tapping it uploads a new one through `/api/me/profile`.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    String t(String key) => AppTranslations.translate(context, ref, key);

    return profile.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => popOrGoHome(context),
          ),
          title: Text(t('settings_title')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => popOrGoHome(context),
          ),
          title: Text(t('settings_title')),
        ),
        body: Center(child: Text(t('settings_load_error'))),
      ),
      data: (user) => _SettingsBody(user: user),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCover = user.coverUrl.trim().isNotEmpty;
    final body = Stack(
      children: [
        ListView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
          ),
          children: [
            GroupBannerHeader(
              url: user.coverUrl,
              title: user.name,
              avatarUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
              extendBehindTop: true,
              showEditBadges: true,
              onBannerTap: () => startCoverFlow(context, ref),
              onAvatarTap: () => startAvatarFlow(context, ref),
            ),
            SettingsBioRow(
              user: user,
              onQrTap: () => context.push('/settings/qr'),
              onEditName: () => context.push('/settings/name'),
            ),
            const Divider(height: 8),
            SettingsSections(user: user),
          ],
        ),
        DetailsFloatingChrome(
          onBanner: hasCover,
          title: AppTranslations.translate(context, ref, 'settings_title'),
          onBack: () => popOrGoHome(context),
        ),
      ],
    );

    if (!hasCover) return Scaffold(body: body);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(body: body),
    );
  }
}
