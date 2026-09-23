import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../messages/data/models/chat_models.dart';
import '../../messages/providers/chat_provider.dart';
import 'privacy_people_provider.dart';

/// Picks one DM peer who has no choice yet. Privacy mode only ever reaches
/// the other side of a DM, so a DM is the whole candidate list.
Future<ChatConversation?> pickPrivacyPerson(BuildContext context) =>
    showModalBottomSheet<ChatConversation>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _Picker(),
    );

class _Picker extends ConsumerStatefulWidget {
  const _Picker();

  @override
  ConsumerState<_Picker> createState() => _PickerState();
}

class _PickerState extends ConsumerState<_Picker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final chat = ref.watch(chatProvider);
    final chosen = ref.watch(privacyPeopleProvider);
    final q = _query.trim().toLowerCase();
    final candidates = [
      for (final c in chat.dms)
        if (c.hasDmPeer &&
            !c.isAccountDeleted &&
            !chosen.containsKey(c.peerUserId) &&
            c.displayTitle(chat.currentUserId).toLowerCase().contains(q))
          c,
    ];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                t('privacy_people_pick_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: t('privacy_people_search'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: candidates.isEmpty
                  ? Center(child: Text(t('privacy_people_pick_empty')))
                  : ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (_, i) {
                        final c = candidates[i];
                        final title = c.displayTitle(chat.currentUserId);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          leading: AppAvatar(
                            size: 40,
                            url: c.peerUserAvatar,
                            name: title,
                          ),
                          title: Text(title),
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
