import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../local-backup/platform/backup_folder_channel.dart';
import '../../messages/data/local/chat_sidebar_cache.dart';
import '../../messages/data/models/chat_conversation.dart';
import '../../messages/providers/chat_provider.dart';

/// Documents/AbabilX/Exports on Android (survives an uninstall, visible in
/// the Files app), else the app's own documents folder.
Future<Directory> chatExportsDir() async {
  var base = '';
  try {
    base = (await const BackupFolderChannel().defaultFolder()).path;
  } catch (_) {}
  if (base.isEmpty) base = (await getApplicationDocumentsDirectory()).path;
  final dir = Directory('$base/Exports');
  await dir.create(recursive: true);
  return dir;
}

/// The chats a message is filed under: the live list, else the sidebar
/// cache (a chat missing from both exports as "Chat").
Future<Map<String, ChatConversation>> exportConversations(
  Ref ref,
  String userId,
) async {
  final chat = ref.read(chatProvider);
  var all = [...chat.channels, ...chat.dms];
  if (all.isEmpty) {
    try {
      final cached = await ChatSidebarCache(
        ref.read(chatLocalDbProvider),
      ).read(userId);
      if (cached != null) all = [...cached.channels, ...cached.dms];
    } catch (_) {}
  }
  return {for (final c in all) c.id: c};
}
