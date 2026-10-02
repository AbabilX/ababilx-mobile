import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/text/byte_size.dart';
import '../../messages/chat_icon.dart';
import '../local_backup_provider.dart';

/// Signal's restore banner over the chat list: a rounded pill with a history
/// clock, the size read so far against the whole file, and a ring that fills.
/// The restore runs behind it while the person uses the app; tapping it
/// offers to stop.
class LocalBackupRestoreBanner extends ConsumerWidget {
  const LocalBackupRestoreBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String tr(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final read = ref.watch(localBackupProvider.select((s) => s.bytesRead));
    final total = ref.watch(localBackupProvider.select((s) => s.bytesTotal));
    final fraction = total > 0 ? (read / total).clamp(0.0, 1.0) : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Material(
        color: colors.surfaceContainerHigh,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showDetails(context, ref),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Row(
              children: [
                ChatIcon(
                  HugeIcons.strokeRoundedHistory,
                  size: 24,
                  color: colors.onSurface,
                  strokeWidth: 1.5,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    tr('local_backup_banner_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (total > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    tr('local_backup_banner_size')
                        .replaceAll('{a}', formatBytes(read))
                        .replaceAll('{b}', formatBytes(total)),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 2.5,
                    strokeCap: StrokeCap.round,
                    backgroundColor: colors.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showDetails(BuildContext context, WidgetRef ref) {
    String tr(String key) => AppTranslations.translate(context, ref, key);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheet) {
        final theme = Theme.of(sheet);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('local_backup_banner_title'),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  tr('local_backup_banner_body'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(sheet),
                  child: Text(tr('local_backup_banner_continue')),
                ),
                const SizedBox(height: 4),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: () {
                    ref.read(localBackupProvider.notifier).cancel();
                    Navigator.pop(sheet);
                  },
                  child: Text(tr('local_backup_banner_stop')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
