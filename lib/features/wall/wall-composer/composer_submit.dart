import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';
import 'composer_encode.dart';

Future<void> submitWallComposer({
  required WidgetRef ref,
  required BuildContext context,
  required String plain,
  required Map<String, String> mentions,
  required WallCategory? category,
  required List<WallAttachmentInput> pending,
}) async {
  final hasCat = category != null && plain.contains('#${category.label}');
  await ref
      .read(wallProvider.notifier)
      .createPost(
        body: encodeWallBody(
          plain: plain.isEmpty ? ' ' : plain,
          mentionByLabel: mentions,
          category: hasCat ? category : null,
        ),
        category: hasCat ? category.slug : null,
        attachments: pending.isEmpty ? null : pending,
        mentionedUserIds: mentions.isEmpty
            ? null
            : mentions.values.toSet().toList(),
      );
  if (context.mounted) Navigator.pop(context);
}
