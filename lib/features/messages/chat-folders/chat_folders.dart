import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/chat_provider.dart';

/// A chat-list folder the user made (Telegram's folders): a name and the
/// chats put in it. Device-local and per account, like the pill order — how
/// someone files their own chats is nothing the server needs.
class ChatFolder {
  const ChatFolder({required this.id, required this.name, required this.ids});

  final String id;
  final String name;

  /// Conversation ids. A chat that left the list (deleted, left) simply
  /// matches nothing.
  final Set<String> ids;

  ChatFolder copyWith({String? name, Set<String>? ids}) =>
      ChatFolder(id: id, name: name ?? this.name, ids: ids ?? this.ids);

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 'c': ids.toList()};

  static ChatFolder? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], name = raw['n'], ids = raw['c'];
    if (id is! String || name is! String || ids is! List) return null;
    return ChatFolder(id: id, name: name, ids: {...ids.whereType<String>()});
  }
}

const maxChatFolders = 10;
const maxChatFolderName = 24;

class ChatFoldersNotifier extends Notifier<List<ChatFolder>> {
  String _user = '';

  String get _key => 'chat_folders_v1:$_user';

  @override
  List<ChatFolder> build() {
    _user = ref.watch(chatProvider.select((s) => s.currentUserId));
    if (_user.isNotEmpty) _load();
    return const [];
  }

  Future<void> _load() async {
    final user = _user;
    try {
      final raw = await SharedPreferencesAsync().getString(_key);
      if (raw == null || user != _user) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      state = [...list.map(ChatFolder.fromJson).nonNulls];
    } catch (_) {}
  }

  Future<void> _save(List<ChatFolder> next) async {
    state = next;
    if (_user.isEmpty) return;
    try {
      await SharedPreferencesAsync().setString(
        _key,
        jsonEncode([for (final f in next) f.toJson()]),
      );
    } catch (_) {}
  }

  /// Null when the folder limit is reached.
  Future<ChatFolder?> create(String name, Set<String> ids) async {
    if (state.length >= maxChatFolders) return null;
    final folder = ChatFolder(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: name,
      ids: ids,
    );
    await _save([...state, folder]);
    return folder;
  }

  Future<void> update(String id, {String? name, Set<String>? ids}) => _save([
    for (final f in state) f.id == id ? f.copyWith(name: name, ids: ids) : f,
  ]);

  Future<void> remove(String id) => _save([
    for (final f in state)
      if (f.id != id) f,
  ]);

  /// Puts [conversationId] in exactly the folders named by [folderIds].
  Future<void> setFoldersFor(String conversationId, Set<String> folderIds) =>
      _save([
        for (final f in state)
          f.copyWith(
            ids: folderIds.contains(f.id)
                ? {...f.ids, conversationId}
                : ({...f.ids}..remove(conversationId)),
          ),
      ]);
}

final chatFoldersProvider =
    NotifierProvider<ChatFoldersNotifier, List<ChatFolder>>(
      ChatFoldersNotifier.new,
    );
