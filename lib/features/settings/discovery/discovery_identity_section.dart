import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import '../../profile/providers/profile_provider.dart';
import '../account-setup/account_email_form.dart';

/// What people can find you by: the email and username this account has,
/// or a way to add each one that is missing. An email is added with a code
/// sent to it; the username has its own screen. The phone field sits under
/// this section on the Discovery page.
class DiscoveryIdentitySection extends ConsumerWidget {
  const DiscoveryIdentitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final user = ref.watch(profileProvider).valueOrNull;
    final email = user?.email ?? '';
    final username = user?.username ?? '';
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (email.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t('discovery_add_email'),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  t('discovery_add_email_body'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                const AccountEmailForm(),
              ],
            ),
          )
        else
          _Known(
            icon: HugeIcons.strokeRoundedMail01,
            label: t('email_field'),
            value: email,
          ),
        if (username.isEmpty)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: const ChatIcon(HugeIcons.strokeRoundedAt),
            title: Text(t('discovery_add_username')),
            subtitle: Text(t('discovery_add_username_body')),
            trailing: const ChatIcon(HugeIcons.strokeRoundedArrowRight01),
            onTap: () => context.push('/settings/username'),
          )
        else
          _Known(
            icon: HugeIcons.strokeRoundedAt,
            label: t('settings_username'),
            value: '@$username',
            onTap: () => context.push('/settings/username'),
          ),
      ],
    );
  }
}

class _Known extends StatelessWidget {
  const _Known({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    leading: ChatIcon(icon),
    title: Text(label),
    subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    onTap: onTap,
  );
}
