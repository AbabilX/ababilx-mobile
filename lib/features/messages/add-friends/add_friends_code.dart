import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_capsule.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../privacy-mode/privacy_mode_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../settings/qr/my_qr_card.dart';
import '../../settings/qr/my_qr_empty.dart';
import '../../settings/qr/my_qr_private.dart';
import '../chat-people/user_qr_payload.dart';

/// Your link and your code, the half of the exchange you hold up. Same
/// handle the Settings QR screen carries; nothing else is in either.
class AddFriendsCode extends ConsumerWidget {
  const AddFriendsCode({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).valueOrNull;
    final username = user?.username ?? '';
    if (ref.watch(privacyModeProvider)) return const MyQrPrivate();
    if (username.isEmpty) return const MyQrEmpty();

    String t(String key) => AppTranslations.translate(context, ref, key);
    final link = buildUserLink(username);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: link));
      if (context.mounted) showAppToast(context, t('add_friends_copied'));
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewPaddingOf(context).bottom + 24,
      ),
      children: [
        MyQrCard(
          payload: buildUserQrPayload(username),
          name: user?.name ?? '',
          username: username,
        ),
        const SizedBox(height: 16),
        // The link itself, readable; tapping it copies it.
        AppCapsule(
          label: link,
          icon: HugeIcons.strokeRoundedLink01,
          expand: true,
          trailing: HugeIcon(
            icon: HugeIcons.strokeRoundedCopy01,
            size: 18,
            color: muted,
          ),
          onTap: copy,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppCapsule(
              label: t('add_friends_share'),
              icon: HugeIcons.strokeRoundedShare01,
              selected: true,
              onTap: () => SharePlus.instance.share(
                ShareParams(
                  text: t('add_friends_share_text').replaceAll('{link}', link),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AppCapsule(
              label: t('add_friends_find'),
              icon: HugeIcons.strokeRoundedSearch01,
              onTap: () => context.push('/messages/people/find'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          t('add_friends_code_hint'),
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
      ],
    );
  }
}
