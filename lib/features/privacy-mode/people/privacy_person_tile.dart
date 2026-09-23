import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat-details/details_tile.dart';
import '../../messages/chat_icon.dart';
import '../privacy_mode_provider.dart';
import 'privacy_people_provider.dart';
import 'privacy_person.dart';
import 'privacy_person_sheet.dart';

/// "Privacy with this person" on a DM's details screen. The value underneath
/// says what applies to them right now, so the row answers the question
/// without being opened.
class PrivacyPersonTile extends ConsumerWidget {
  const PrivacyPersonTile({
    super.key,
    required this.userId,
    required this.displayName,
    this.name = '',
    this.avatarUrl = '',
  });

  final String userId;
  final String displayName;
  final String name;
  final String avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final mode =
        ref.watch(privacyPeopleProvider.select((m) => m[userId]?.mode)) ??
        PrivacyPersonMode.follow;
    final switchOn = ref.watch(privacyModeProvider);
    return DetailsTile(
      icon: const ChatIcon(HugeIcons.strokeRoundedShield01),
      title: t('privacy_person_tile'),
      value: privacyPersonValue(t, mode, switchOn: switchOn),
      onTap: () => showPrivacyPersonSheet(
        context,
        ref,
        displayName: displayName,
        person: PrivacyPerson(
          userId: userId,
          mode: mode,
          name: name,
          avatarUrl: avatarUrl,
        ),
      ),
    );
  }
}
