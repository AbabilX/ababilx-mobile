import 'dart:convert';
import 'dart:io';

import '../format/chat_export_format.dart';
import '../format/chat_export_manifest.dart';

/// One file the zip takes as it is: [source] on disk, [name] inside the zip.
/// [store] skips compression — photos and video are compressed already, and
/// the zip library deflates in memory, which a long video would not survive.
class ChatExportEntry {
  const ChatExportEntry(this.source, this.name, {this.store = false});

  final String source;
  final String name;
  final bool store;
}

class _Chat {
  _Chat(this.info, this.dir);

  final ExportedChat info;
  final Directory dir;
  final text = StringBuffer();
  final json = StringBuffer();
  final media = <String, String>{};
  var count = 0;
  var lastAt = '';
}

/// Builds the zip's text files chat by chat while the store is read oldest
/// first across every chat. Each chat's text waits in memory and is appended
/// to its file every 64 KB, so a phone with hundreds of chats never holds
/// hundreds of open files.
class ChatExportStaging {
  ChatExportStaging(this.root);

  final Directory root;
  final _chats = <String, _Chat>{};
  final _media = <ChatExportEntry>[];

  static const _flushAt = 64 * 1024;

  bool has(String conversationId) => _chats.containsKey(conversationId);

  /// Starts a chat's folder; the first message of a chat calls it.
  Future<void> open(String id, String title, String kind) async {
    if (_chats.containsKey(id)) return;
    final folder = ChatExportFormat.chatFolder(_chats.length + 1, title);
    final dir = Directory('${root.path}/$folder');
    await dir.create(recursive: true);
    final chat = _Chat(
      ExportedChat(
        id: id,
        title: title,
        kind: kind,
        folder: folder,
        messages: 0,
      ),
      dir,
    );
    chat.text.writeln(title);
    chat.text.writeln();
    chat.json.write('{"chat":${jsonEncode(chat.info.toJson())},"messages":[');
    _chats[id] = chat;
  }

  /// The path a file takes inside its chat's folder, or null when it is
  /// already in (one file shared by several messages goes in once).
  String? reserveMedia(String id, String url, String name, String source) {
    final chat = _chats[id]!;
    final known = chat.media[url];
    if (known != null) return known;
    final path =
        '${ChatExportFormat.mediaDir}/${chat.media.length + 1}-'
        '${ChatExportFormat.safeName(name)}';
    chat.media[url] = path;
    _media.add(
      ChatExportEntry(
        source,
        '${ChatExportFormat.chatsDir}/${chat.info.folder}/$path',
        store: true,
      ),
    );
    return path;
  }

  /// The path [reserveMedia] gave this url in this chat, if any.
  String? mediaFor(String id, String url) => _chats[id]?.media[url];

  Future<void> add(String id, ExportedMessage message) async {
    final chat = _chats[id]!;
    if (chat.count > 0) chat.json.write(',');
    chat.json.write(jsonEncode(message.toJson()));
    chat.text.writeln(ChatExportFormat.textLine(message));
    chat.count++;
    chat.lastAt = message.at;
    if (chat.text.length + chat.json.length > _flushAt) await _flush(chat);
  }

  Future<void> _flush(_Chat chat) async {
    await _append(ChatExportFormat.messagesText, chat, chat.text);
    await _append(ChatExportFormat.messagesJson, chat, chat.json);
  }

  Future<void> _append(String file, _Chat chat, StringBuffer buffer) async {
    if (buffer.isEmpty) return;
    await File(
      '${chat.dir.path}/$file',
    ).writeAsString(buffer.toString(), mode: FileMode.append, flush: true);
    buffer.clear();
  }

  /// Ends every chat's files and writes `chats.json` and the README. Returns
  /// the manifest and every file the zip takes.
  Future<(ChatExportManifest, List<ChatExportEntry>)> finish({
    required String accountId,
    required String accountName,
    required DateTime at,
  }) async {
    final entries = <ChatExportEntry>[];
    final chats = <ExportedChat>[];
    for (final chat in _chats.values) {
      chat.json.write(']}');
      await _flush(chat);
      final base = '${ChatExportFormat.chatsDir}/${chat.info.folder}';
      for (final file in [
        ChatExportFormat.messagesText,
        ChatExportFormat.messagesJson,
      ]) {
        entries.add(ChatExportEntry('${chat.dir.path}/$file', '$base/$file'));
      }
      chats.add(
        ExportedChat(
          id: chat.info.id,
          title: chat.info.title,
          kind: chat.info.kind,
          folder: chat.info.folder,
          messages: chat.count,
          lastAt: chat.lastAt,
        ),
      );
    }
    final manifest = ChatExportManifest(
      exportedAt: at.toUtc().toIso8601String(),
      accountId: accountId,
      accountName: accountName,
      chats: chats,
    );
    final manifestFile = File('${root.path}/${ChatExportFormat.manifest}');
    await manifestFile.writeAsString(jsonEncode(manifest.toJson()));
    final readme = File('${root.path}/${ChatExportFormat.readme}');
    await readme.writeAsString(ChatExportFormat.readmeText);
    return (
      manifest,
      [
        ChatExportEntry(readme.path, ChatExportFormat.readme),
        ChatExportEntry(manifestFile.path, ChatExportFormat.manifest),
        ...entries,
        ..._media,
      ],
    );
  }
}
