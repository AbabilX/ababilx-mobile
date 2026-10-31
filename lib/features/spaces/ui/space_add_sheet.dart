import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../data/space_failure.dart';
import '../data/space_invite.dart';
import '../data/space_models.dart';
import '../providers/spaces_providers.dart';
import 'space_form_sheet.dart';

Future<T?> _sheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => child,
    );

/// The rail's + : create or join.
Future<void> showAddSpaceSheet(BuildContext context, WidgetRef ref) async {
  final pick = await _sheet<String>(
    context,
    Builder(
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        Widget tile(
          String key,
          List<List<dynamic>> icon,
          String title,
          String sub,
        ) => ListTile(
          leading: HugeIcon(icon: icon, color: c.onSurface, size: 24),
          title: Text(title),
          subtitle: Text(sub),
          onTap: () => Navigator.pop(ctx, key),
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(
                'create',
                HugeIcons.strokeRoundedPlusSign,
                'Create a space',
                'Start a community with its own channels',
              ),
              tile(
                'join',
                HugeIcons.strokeRoundedUserGroup,
                'Join with a link',
                'Paste an invite link someone sent you',
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
  if (!context.mounted) return;
  if (pick == 'create') return showCreateSpaceSheet(context, ref);
  if (pick == 'join') return showJoinSpaceSheet(context, ref);
}

Future<void> _landed(WidgetRef ref, SpaceSummary space) async {
  await ref.read(selectedSpaceNotifierProvider.notifier).select(space.id);
  await ref.read(spacesListProvider.notifier).refresh();
}

String _why(Object e) => spaceFailureCopy(classifySpaceError(e)).title;

Future<void> showCreateSpaceSheet(BuildContext context, WidgetRef ref) =>
    _sheet<void>(
      context,
      SpaceFormSheet(
        title: 'Create a space',
        hint: 'Space name',
        action: 'Create',
        note: 'Space channels are not end-to-end encrypted.',
        maxLength: 50,
        validate: (v) =>
            v.trim().length < 2 ? 'Use at least 2 characters' : null,
        submit: (v) async {
          try {
            await _landed(
              ref,
              await ref.read(spacesBackendProvider).createSpace(v.trim()),
            );
            return null;
          } catch (e) {
            return _why(e);
          }
        },
      ),
    );

Future<void> showJoinSpaceSheet(
  BuildContext context,
  WidgetRef ref,
) => _sheet<void>(
  context,
  SpaceFormSheet(
    title: 'Join a space',
    hint: 'https://www.ababilx.com/s/…',
    action: 'Join',
    maxLength: 200,
    validate: (v) =>
        parseInviteCode(v) == null ? 'That is not an AbabilX space link' : null,
    submit: (v) async {
      try {
        await _landed(
          ref,
          await ref.read(spacesBackendProvider).joinInvite(parseInviteCode(v)!),
        );
        return null;
      } catch (e) {
        return _why(e);
      }
    },
  ),
);
