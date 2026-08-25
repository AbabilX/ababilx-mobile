import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_translations.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';

class PolicyAcceptCard extends ConsumerStatefulWidget {
  const PolicyAcceptCard({super.key});

  @override
  ConsumerState<PolicyAcceptCard> createState() => _PolicyAcceptCardState();
}

class _PolicyAcceptCardState extends ConsumerState<PolicyAcceptCard> {
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileProvider.notifier).acceptPolicy();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppTranslations.translate(context, ref, 'policy_error');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _declineAndSignOut() async {
    setState(() => _busy = true);
    await ref.read(authProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black.withValues(alpha: 0.7),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.outline, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.translate(context, ref, 'policy_title'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppTranslations.translate(
                        context,
                        ref,
                        'policy_subtitle',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final key in [
                      'policy_bullet_1',
                      'policy_bullet_2',
                      'policy_bullet_3',
                      'policy_bullet_4',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.circle, size: 6, color: colors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                AppTranslations.translate(context, ref, key),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => launchUrl(
                        Uri.parse(ApiConstants.webPrivacyPolicyUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        AppTranslations.translate(
                          context,
                          ref,
                          'policy_read_full',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: colors.error, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _accept,
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                AppTranslations.translate(
                                  context,
                                  ref,
                                  'policy_accept',
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _busy ? null : _declineAndSignOut,
                        child: Text(
                          AppTranslations.translate(
                            context,
                            ref,
                            'policy_decline_signout',
                          ),
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
