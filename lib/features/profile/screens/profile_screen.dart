import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/widgets/battery_optimization_tile.dart';
import '../../notifications/widgets/notification_permission_tile.dart';
import '../providers/profile_provider.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../auth/widgets/qr_login_flow.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppTranslations.translate(context, ref, 'profile'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: colors.surfaceContainerLow,
              foregroundColor: colors.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => ref.read(profileProvider.notifier).refresh(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: profileAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: colors.primary,
            strokeWidth: 2.5,
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outline),
                ),
                child: Icon(Icons.error_outline_rounded,
                    color: colors.error, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                e.toString(),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (user) => ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            ShellPillMetrics.contentBottomInset,
          ),
          children: [
            const NotificationPermissionTile(),
            const BatteryOptimizationTile(),
            // ── Avatar + Name Card (Symmetrical M3 Squircle Sheet) ─────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: colors.outline, width: 1.0),
              ),
              child: Column(
                children: [
                  // Homepage-style rounded-square avatar (radius 8)
                  AppAvatar(
                    size: 96,
                    url: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
                    name: user.name,
                    backgroundColor: colors.surfaceContainer,
                    border: Border.all(color: colors.outline, width: 1.5),
                    fallback: Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name (Jakarta Sans)
                  Text(
                    user.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Email
                  Text(
                    user.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFCAC4D0),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Plan badge capsule: Flat Tonal Solid Purple capsule
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF381E72),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: colors.outline,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      user.effectivePlan.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFE8DEF8),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Info listings (Solid Flat Panel with border) ───────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: colors.outline, width: 1.0),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.alternate_email_rounded,
                    label: AppTranslations.translate(context, ref, 'provider'),
                    value: user.provider.toUpperCase(),
                  ),
                  Divider(color: colors.outline, height: 1),
                  _InfoRow(
                    icon: Icons.code_rounded,
                    label: AppTranslations.translate(context, ref, 'github_connection'),
                    value: user.githubUsername.isNotEmpty
                        ? '@${user.githubUsername}'
                        : 'Not connected',
                    valueColor: user.githubUsername.isNotEmpty
                        ? colors.onSurface
                        : const Color(0xFFCAC4D0),
                  ),
                  Divider(color: colors.outline, height: 1),
                  _InfoRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: AppTranslations.translate(context, ref, 'slack_workspace'),
                    value: user.slackConnected ? 'Connected' : 'Not connected',
                    valueColor: user.slackConnected
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFCAC4D0),
                  ),
                  Divider(color: colors.outline, height: 1),
                  // Approve a desktop/web sign-in by scanning its QR code.
                  _InfoRow(
                    icon: Icons.qr_code_scanner_rounded,
                    label: AppTranslations.translate(context, ref, 'qr_login_title'),
                    value: AppTranslations.translate(context, ref, 'qr_login_subtitle'),
                    onTap: () => QrLoginFlow.start(context, ref),
                  ),
                  Divider(color: colors.outline, height: 1),
                  // Interactive Language Selector Row!
                  _InfoRow(
                    icon: Icons.translate_rounded,
                    label: AppTranslations.translate(context, ref, 'app_language'),
                    value: user.appLanguage.toUpperCase() == 'BN' ? 'বাংলা (BN)' : 'English (EN)',
                    onTap: () async {
                      final selectedLang = await showDialog<String>(
                        context: context,
                        builder: (dialogCtx) => Dialog(
                          backgroundColor: colors.surfaceContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                            side: BorderSide(color: colors.outline),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppTranslations.translate(context, ref, 'app_language'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // English option
                                ListTile(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('English (EN)', style: TextStyle(fontWeight: FontWeight.w600)),
                                  trailing: user.appLanguage.toLowerCase() == 'en'
                                      ? Icon(Icons.check_circle_rounded, color: colors.primary)
                                      : null,
                                  onTap: () => Navigator.pop(dialogCtx, 'en'),
                                ),
                                const SizedBox(height: 8),
                                // Bangla option
                                ListTile(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('বাংলা (BN)', style: TextStyle(fontWeight: FontWeight.w600)),
                                  trailing: user.appLanguage.toLowerCase() == 'bn'
                                      ? Icon(Icons.check_circle_rounded, color: colors.primary)
                                      : null,
                                  onTap: () => Navigator.pop(dialogCtx, 'bn'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      if (selectedLang != null) {
                        await ref.read(profileProvider.notifier).updateLanguage(selectedLang);
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Sign Out Button (Flat Red Tonal Capsule style) ─────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => Dialog(
                      backgroundColor: colors.surfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(color: colors.outline),
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
                                color: colors.errorContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.logout_rounded,
                                  color: colors.error, size: 28),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppTranslations.translate(context, ref, 'sign_out'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppTranslations.translate(context, ref, 'confirm_signout'),
                              style: const TextStyle(
                                  color: Color(0xFFCAC4D0), fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogCtx, false),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: colors.onSurface,
                                      side: BorderSide(color: colors.outline),
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                    child: Text(AppTranslations.translate(context, ref, 'cancel')),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogCtx, true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colors.error,
                                      foregroundColor: colors.onError,
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                    child: Text(
                                      AppTranslations.translate(context, ref, 'sign_out'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E1B1B),
                  foregroundColor: const Color(0xFFF2B8B5),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFF601410), width: 1.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      AppTranslations.translate(context, ref, 'sign_out'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
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
    this.valueColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fallbackColor = colors.onSurface;

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
                color: Color(0xFFCAC4D0),
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? fallbackColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 20, color: colors.primary),
          ]
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }

    return content;
  }
}
