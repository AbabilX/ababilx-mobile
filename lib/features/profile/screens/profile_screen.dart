import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
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
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface2,
              foregroundColor: AppColors.textMuted,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => ref.read(profileProvider.notifier).refresh(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.indigo, strokeWidth: 2.5)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.error_outline_rounded, color: AppColors.textMuted, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                e.toString(),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (user) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            // ── Avatar + Name Card (Premium Deck) ──────────────────────────
            GlassCard(
              borderRadius: 28,
              borderColor: AppColors.border,
              backgroundColor: AppColors.surface2.withOpacity(0.8),
              child: Column(
                children: [
                  // Asymmetric Squircle Avatar Frame (Shape tension!)
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(26),
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(26),
                      ),
                      border: Border.all(
                        color: AppColors.indigo.withOpacity(0.24),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.indigoGlow.withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.5),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(23),
                          topRight: Radius.circular(9),
                          bottomLeft: Radius.circular(9),
                          bottomRight: Radius.circular(23),
                        ),
                        child: user.avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: user.avatarUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => const Icon(
                                  Icons.person_rounded,
                                  size: 36,
                                  color: AppColors.indigoLight,
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                size: 36,
                                color: AppColors.indigoLight,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name (Emphasized typography)
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Email
                  Text(
                    user.email,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Plan badge capsule
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.indigo.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: AppColors.indigo.withOpacity(0.2),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      user.plan.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.indigoLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Info listings (Translucent Glass Panel) ────────────────────
            GlassCard(
              borderRadius: 24,
              borderColor: AppColors.border,
              backgroundColor: AppColors.surface.withOpacity(0.3),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.alternate_email_rounded,
                    label: 'Provider',
                    value: user.provider.toUpperCase(),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _InfoRow(
                    icon: Icons.code_rounded,
                    label: 'GitHub Connection',
                    value: user.githubUsername.isNotEmpty
                        ? '@${user.githubUsername}'
                        : 'Not connected',
                    valueColor: user.githubUsername.isNotEmpty
                        ? AppColors.text
                        : AppColors.textMuted,
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _InfoRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Slack Workspace',
                    value: user.slackConnected ? 'Connected' : 'Not connected',
                    valueColor: user.slackConnected
                        ? AppColors.green
                        : AppColors.textMuted,
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _InfoRow(
                    icon: Icons.translate_rounded,
                    label: 'Application Language',
                    value: user.appLanguage.toUpperCase(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Sign Out Button (Filled Red Tonal Capsule style) ───────────
            Material(
              color: AppColors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(100),
              child: InkWell(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: AppColors.surface2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(Icons.logout_rounded, color: AppColors.red, size: 28),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Sign out',
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Are you sure you want to sign out?',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.textMuted,
                                      side: const BorderSide(color: AppColors.border),
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.red,
                                      foregroundColor: Colors.white,
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(authProvider.notifier).signOut();
                  }
                },
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppColors.red.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, size: 18, color: AppColors.red),
                      SizedBox(width: 8),
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          color: AppColors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.indigoLight),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
