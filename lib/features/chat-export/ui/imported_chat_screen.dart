import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../format/chat_export_format.dart';
import '../import/chat_import_store.dart';
import 'imported_message_bubble.dart';
import 'imported_time.dart';

final _messagesProvider = FutureProvider.autoDispose
    .family<List<ExportedMessage>, String>(
      (ref, chatDir) => ChatImportStore.messages(Directory(chatDir)),
    );

/// One imported chat, read-only: no composer, no replies, nothing sent.
class ImportedChatScreen extends ConsumerWidget {
  const ImportedChatScreen({
    super.key,
    required this.archiveId,
    required this.folder,
  });

  final String archiveId;
  final String folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final archives = ref.watch(importedArchivesProvider).valueOrNull;
    ImportedArchive? archive;
    for (final a in archives ?? const <ImportedArchive>[]) {
      if (a.id == archiveId) archive = a;
    }
    final chat = archive?.chat(folder);
    final dir = archive?.chatDir(folder);
    final messages = dir == null
        ? null
        : ref.watch(_messagesProvider(dir.path));
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(chat?.title ?? ''),
      ),
      body: archive == null || dir == null || messages == null
          ? Center(
              child: archives == null
                  ? const CircularProgressIndicator()
                  : Text(t('chat_import_error_unreadable')),
            )
          : messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  Center(child: Text(t('chat_import_error_unreadable'))),
              data: (list) => _Timeline(
                messages: list,
                ownId: archive!.manifest.accountId,
                isGroup: chat?.kind == 'group',
                chatDir: dir.path,
              ),
            ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.messages,
    required this.ownId,
    required this.isGroup,
    required this.chatDir,
  });

  final List<ExportedMessage> messages;
  final String ownId;
  final bool isGroup;
  final String chatDir;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // Newest at the bottom, opened there, as a chat is.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final index = messages.length - 1 - i;
        final m = messages[index];
        final day = importedDate(m.at);
        final newDay =
            index == 0 || importedDate(messages[index - 1].at) != day;
        return Column(
          children: [
            if (newDay)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(day, style: TextStyle(color: muted, fontSize: 12)),
              ),
            ImportedMessageBubble(
              message: m,
              mine: m.senderId == ownId,
              showSender: isGroup,
              chatDir: chatDir,
            ),
          ],
        );
      },
    );
  }
}
