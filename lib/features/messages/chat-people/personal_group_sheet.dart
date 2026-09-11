import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_conversation.dart';
import '../providers/chat_provider.dart';
import '../providers/messageable_people_provider.dart';

Future<ChatConversation?> showPersonalGroupSheet(
  BuildContext context,
  WidgetRef ref,
) => showModalBottomSheet<ChatConversation>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const PersonalGroupSheet(),
);

class PersonalGroupSheet extends ConsumerStatefulWidget {
  const PersonalGroupSheet({super.key});

  @override
  ConsumerState<PersonalGroupSheet> createState() => _PersonalGroupSheetState();
}

class _PersonalGroupSheetState extends ConsumerState<PersonalGroupSheet> {
  final _name = TextEditingController();
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidates = ref.watch(groupInvitablePeopleProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      builder: (_, controller) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: AppTranslations.translate(
                    context,
                    ref,
                    'chat_group_name',
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: candidates.length,
                itemBuilder: (_, index) {
                  final user = candidates[index];
                  return CheckboxListTile(
                    secondary: AppAvatar(
                      size: 40,
                      url: user.avatarUrl,
                      name: user.name,
                    ),
                    title: Text(user.name),
                    subtitle: user.username.isEmpty
                        ? null
                        : Text('@${user.username}'),
                    value: _selected.contains(user.userId),
                    onChanged: (checked) => setState(() {
                      checked == true
                          ? _selected.add(user.userId)
                          : _selected.remove(user.userId);
                    }),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed:
                    _saving || _name.text.trim().isEmpty || _selected.isEmpty
                    ? null
                    : _create,
                child: Text(
                  AppTranslations.translate(context, ref, 'chat_create'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      final group = await ref
          .read(chatProvider.notifier)
          .createPersonalGroup(_name.text.trim(), _selected.toList());
      if (mounted) Navigator.pop(context, group);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
