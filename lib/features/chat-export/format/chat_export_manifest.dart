import 'chat_export_format.dart';

/// One chat in `chats.json`.
class ExportedChat {
  const ExportedChat({
    required this.id,
    required this.title,
    required this.kind,
    required this.folder,
    required this.messages,
    this.lastAt = '',
  });

  final String id;
  final String title;

  /// `dm`, `group` or `self`.
  final String kind;

  /// Under `chats/`.
  final String folder;
  final int messages;
  final String lastAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind,
    'folder': folder,
    'messages': messages,
    'last_at': lastAt,
  };

  factory ExportedChat.fromJson(Map<String, dynamic> j) => ExportedChat(
    id: '${j['id'] ?? ''}',
    title: '${j['title'] ?? ''}',
    kind: '${j['kind'] ?? 'group'}',
    folder: '${j['folder'] ?? ''}',
    messages: (j['messages'] as num?)?.toInt() ?? 0,
    lastAt: '${j['last_at'] ?? ''}',
  );
}

/// `chats.json`: who exported, when, and the chats in the zip.
class ChatExportManifest {
  const ChatExportManifest({
    required this.exportedAt,
    required this.accountId,
    required this.accountName,
    required this.chats,
  });

  final String exportedAt;

  /// The exporting account: its messages are drawn on the right.
  final String accountId;
  final String accountName;
  final List<ExportedChat> chats;

  int get messages => chats.fold(0, (sum, c) => sum + c.messages);

  Map<String, dynamic> toJson() => {
    'format': ChatExportFormat.format,
    'version': ChatExportFormat.version,
    'exported_at': exportedAt,
    'account': {'id': accountId, 'name': accountName},
    'chats': [for (final c in chats) c.toJson()],
  };

  /// Null when this is not an AbabilX chat export, or a newer one.
  static ChatExportManifest? tryParse(Object? json) {
    if (json is! Map) return null;
    if (json['format'] != ChatExportFormat.format) return null;
    final v = json['version'];
    if (v is! num || v > ChatExportFormat.version) return null;
    final account = json['account'] is Map ? json['account'] as Map : const {};
    return ChatExportManifest(
      exportedAt: '${json['exported_at'] ?? ''}',
      accountId: '${account['id'] ?? ''}',
      accountName: '${account['name'] ?? ''}',
      chats: [
        for (final c in (json['chats'] as List?) ?? const [])
          if (c is Map) ExportedChat.fromJson(Map<String, dynamic>.from(c)),
      ],
    );
  }
}
