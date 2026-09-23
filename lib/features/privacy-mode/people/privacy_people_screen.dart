import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/text/display_name.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../messages/chat_icon.dart';
import '../../messages/nickname/contact_nickname_provider.dart';
import '../../messages/providers/chat_provider.dart';
import '../privacy_mode_provider.dart';
import 'privacy_people_picker.dart';
import 'privacy_people_provider.dart';
import 'privacy_person.dart';
import 'privacy_person_sheet.dart';

/// Settings → Privacy mode → Exceptions: everyone with a choice of their own,
/// newest first, and a way to add one. Opening it re-reads the list, which is
/// how a choice made on another device gets its name and picture.
class PrivacyPeopleScreen extends ConsumerStatefulWidget {
  const PrivacyPeopleScreen({super.key});

  @override
  ConsumerState<PrivacyPeopleScreen> createState() =>
      _PrivacyPeopleScreenState();
}

class _PrivacyPeopleScreenState extends ConsumerState<PrivacyPeopleScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(privacyPeopleProvider.notifier).refresh();
  }

  Future<void> _add() async {
    final conv = await pickPrivacyPerson(context);
    if (conv == null || !mounted) return;
    await showPrivacyPersonSheet(
      context,
      ref,
      displayName: conv.displayTitle(ref.read(chatProvider).currentUserId),
      person: PrivacyPerson(
        userId: conv.peerUserId!,
        mode: PrivacyPersonMode.follow,
        name: conv.peerUserName ?? '',
        avatarUrl: conv.peerUserAvatar ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    String t(String key) => AppTranslations.translate(context, ref, key);
    final people = ref.watch(privacyPeopleProvider).values.toList();
    final nicknames = ref.watch(contactNicknamesProvider);
    final switchOn = ref.watch(privacyModeProvider);
    String nameOf(PrivacyPerson p) =>
        nicknames.forUser(p.userId) ??
        safeDisplayName(
          p.name.isNotEmpty ? p.name : p.username,
          fallback: t('privacy_people_someone'),
        );
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('privacy_people_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: ChatIcon(
              HugeIcons.strokeRoundedUserAdd01,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              t('privacy_people_add'),
              style: TextStyle(color: theme.colorScheme.primary),
            ),
            onTap: _add,
          ),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                t('privacy_people_empty'),
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ),
          for (final p in people)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: AppAvatar(size: 40, url: p.avatarUrl, name: nameOf(p)),
              title: Text(nameOf(p)),
              subtitle: Text(
                privacyPersonValue(t, p.mode, switchOn: switchOn),
                style: TextStyle(color: muted),
              ),
              onTap: () => showPrivacyPersonSheet(
                context,
                ref,
                person: p,
                displayName: nameOf(p),
              ),
            ),
        ],
      ),
    );
  }
}
