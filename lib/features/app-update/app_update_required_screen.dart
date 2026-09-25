import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/app_version.dart';
import '../../core/localization/app_translations.dart';
import '../messages/chat_icon.dart';
import 'app_update_info.dart';
import 'app_update_notes.dart';
import 'app_update_store.dart';

/// Covers the whole app while this build is below the server's floor. There
/// is no way past it but updating: the old build may no longer speak the
/// API correctly, which is the only reason anyone would force this.
class AppUpdateRequiredScreen extends ConsumerStatefulWidget {
  const AppUpdateRequiredScreen({super.key, required this.info});

  final AppUpdateInfo info;

  @override
  ConsumerState<AppUpdateRequiredScreen> createState() =>
      _AppUpdateRequiredScreenState();
}

class _AppUpdateRequiredScreenState
    extends ConsumerState<AppUpdateRequiredScreen> {
  bool _storeFailed = false;

  Future<void> _update() async {
    final opened = await openAppStore(widget.info.storeUrl);
    if (mounted) setState(() => _storeFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    String t(String key) => AppTranslations.translate(context, ref, key);

    return Material(
      color: colors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colors.primaryContainer,
                child: ChatIcon(
                  HugeIcons.strokeRoundedDownload04,
                  size: 28,
                  color: colors.onPrimaryContainer,
                  strokeWidth: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t('app_update_title_required'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  'app_update_body_required',
                ).replaceAll('{version}', widget.info.latestVersion),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t(
                  'app_update_installed',
                ).replaceAll('{version}', appVersionName),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: widget.info.whatsNew.isEmpty
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                        child: AppUpdateNotes(
                          title: t('app_update_whats_new'),
                          notes: widget.info.whatsNew,
                        ),
                      ),
              ),
              if (_storeFailed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    t('app_update_store_failed'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _update,
                  child: Text(t('app_update_action')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
