import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import '../data/backup_choices.dart';
import '../local_backup_provider.dart';

/// "What to back up" and "Chats": the person's own choices. Text is shown as
/// a locked row, on, so nobody wonders whether the messages are in there.
/// What is never backed up (other people's no-save promises) is a sentence
/// under the list, not a switch.
class LocalBackupChoiceRows extends ConsumerWidget {
  const LocalBackupChoiceRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final choices = ref.watch(
      localBackupProvider.select((s) => s.settings.choices),
    );
    final notifier = ref.read(localBackupProvider.notifier);
    void set(BackupChoices next) => notifier.setChoices(next);

    Widget row(
      List<List<dynamic>> icon,
      String key,
      bool value,
      ValueChanged<bool>? onChanged, {
      String? hint,
    }) => SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      secondary: ChatIcon(icon, size: 22, color: muted),
      title: Text(t(key), style: theme.textTheme.bodyLarge),
      subtitle: hint == null
          ? null
          : Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
    );

    Widget header(String key) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(t(key), style: theme.textTheme.labelLarge),
    );

    Widget note(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color ?? muted,
          height: 1.4,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header('local_backup_section_what'),
        row(
          HugeIcons.strokeRoundedMessage01,
          'local_backup_text',
          true,
          null,
          hint: t('local_backup_text_hint'),
        ),
        row(
          HugeIcons.strokeRoundedImage01,
          'local_backup_photos',
          choices.photos,
          (v) => set(choices.copyWith(photos: v)),
        ),
        row(
          HugeIcons.strokeRoundedMic01,
          'local_backup_voice',
          choices.voiceNotes,
          (v) => set(choices.copyWith(voiceNotes: v)),
        ),
        row(
          HugeIcons.strokeRoundedVideo01,
          'local_backup_videos',
          choices.videos,
          (v) => set(choices.copyWith(videos: v)),
        ),
        row(
          HugeIcons.strokeRoundedFile01,
          'local_backup_documents',
          choices.documents,
          (v) => set(choices.copyWith(documents: v)),
        ),
        note(t('local_backup_media_note')),
        header('local_backup_section_chats'),
        row(
          HugeIcons.strokeRoundedUser,
          'local_backup_dms',
          choices.directMessages,
          (v) => set(choices.copyWith(directMessages: v)),
        ),
        row(
          HugeIcons.strokeRoundedUserGroup,
          'local_backup_groups',
          choices.groups,
          (v) => set(choices.copyWith(groups: v)),
        ),
        if (!choices.anyChats)
          note(t('local_backup_nothing'), color: theme.colorScheme.error),
        note(t('local_backup_protected_note')),
      ],
    );
  }
}
