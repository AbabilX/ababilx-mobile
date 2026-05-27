import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.read(profileProvider.notifier).refresh(),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.indigo)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.textMuted, size: 48),
              const SizedBox(height: 12),
              Text(e.toString(),
                  style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
        data: (user) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Avatar + Name card
            GlassCard(
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.indigoGlow,
                    child: user.avatarUrl.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: user.avatarUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.person,
                                size: 40,
                                color: AppColors.indigoLight,
                              ),
                            ),
                          )
                        : const Icon(Icons.person,
                            size: 40, color: AppColors.indigoLight),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  // Plan badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.indigoGlow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.indigo.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      user.plan.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.indigoLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Info rows
            GlassCard(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.alternate_email,
                    label: 'Provider',
                    value: user.provider.toUpperCase(),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _InfoRow(
                    icon: Icons.code,
                    label: 'GitHub',
                    value: user.githubUsername.isNotEmpty
                        ? '@${user.githubUsername}'
                        : 'Not connected',
                    valueColor: user.githubUsername.isNotEmpty
                        ? AppColors.text
                        : AppColors.textMuted,
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _InfoRow(
                    icon: Icons.chat_outlined,
                    label: 'Slack',
                    value: user.slackConnected ? 'Connected' : 'Not connected',
                    valueColor: user.slackConnected
                        ? AppColors.green
                        : AppColors.textMuted,
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _InfoRow(
                    icon: Icons.language,
                    label: 'Language',
                    value: user.appLanguage.toUpperCase(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sign out
            OutlinedButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.surface2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    title: const Text('Sign out',
                        style: TextStyle(color: AppColors.text)),
                    content: const Text(
                      'Are you sure you want to sign out?',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign out',
                            style: TextStyle(color: AppColors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authProvider.notifier).signOut();
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, size: 18),
                  SizedBox(width: 8),
                  Text('Sign Out'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = AppColors.text,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
