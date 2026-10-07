import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_toast.dart';
import '../chat-timeline/composer_attach.dart';
import '../data/models/chat_models.dart';
import '../../../shared/widgets/app_capsule.dart';
import 'task_icons.dart';
import 'task_strings.dart';

/// Picks photos or a file for a task and uploads them through the chat's own
/// path, so they are encrypted wherever any other chat file is. Completes
/// when every transfer has settled; a failure is told, never thrown.
Future<void> attachTaskFiles(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required ComposerAttachKind kind,
  required String failedText,
  required ValueChanged<ChatAttachmentInput> onAdded,
  required ValueChanged<String> onFailed,
  CancelToken? cancelToken,
}) async {
  void fail([String? text]) {
    if (context.mounted) {
      showAppToast(context, text ?? failedText, isError: true);
    }
  }

  try {
    await pickAndUploadAttachment(
      context,
      ref,
      conversationId: conversationId,
      kind: kind,
      onAdded: onAdded,
      onFailed: (url) {
        onFailed(url);
        fail();
      },
      // The native review screen ends on its own Send; here that only means
      // "add these to the task".
      onNativeSendReady: (_) {},
      cancelToken: cancelToken,
    );
  } on ChatAttachmentSizeException catch (error) {
    fail(error.toString());
  } catch (_) {
    fail();
  }
}

/// Photo · File, under the task's fields.
class TaskAttachButtons extends StatelessWidget {
  const TaskAttachButtons({
    super.key,
    required this.strings,
    required this.onAttach,
  });

  final TaskStrings strings;
  final ValueChanged<ComposerAttachKind>? onAttach;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      AppCapsule(
        label: strings.addPhoto,
        icon: TaskIcons.photo,
        onTap: onAttach == null
            ? null
            : () => onAttach!(ComposerAttachKind.gallery),
      ),
      AppCapsule(
        label: strings.addFile,
        icon: TaskIcons.file,
        onTap: onAttach == null
            ? null
            : () => onAttach!(ComposerAttachKind.file),
      ),
    ],
  );
}
