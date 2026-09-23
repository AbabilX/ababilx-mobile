import 'package:equatable/equatable.dart';

class ChatUserSummary extends Equatable {
  const ChatUserSummary({
    required this.userId,
    required this.name,
    this.username = '',
    this.avatarUrl = '',
    this.connection = 'none',
    this.sharedWorkspace = false,
    this.canMessage = false,
    this.privacyMode = false,
  });

  final String userId;
  final String name;
  final String username;
  final String avatarUrl;
  final String connection;
  final bool sharedWorkspace;
  final bool canMessage;

  /// The person has privacy mode on (server migration 0152): nobody can put
  /// them into a group, so group pickers leave them out.
  final bool privacyMode;

  factory ChatUserSummary.fromJson(Map<String, dynamic> json) =>
      ChatUserSummary(
        userId: _jsonString(json['user_id']),
        name: _jsonString(json['name']),
        username: _jsonString(json['username']),
        avatarUrl: _jsonString(json['avatar_url']),
        connection: _jsonString(json['connection'], fallback: 'none'),
        sharedWorkspace: json['shared_workspace'] == true,
        canMessage: json['can_message'] == true,
        privacyMode: json['privacy_mode'] == true,
      );

  @override
  List<Object?> get props => [
    userId,
    name,
    username,
    avatarUrl,
    connection,
    sharedWorkspace,
    canMessage,
    privacyMode,
  ];
}

class ChatConnection extends Equatable {
  const ChatConnection({
    required this.id,
    required this.user,
    required this.status,
    required this.direction,
    required this.createdAt,
    this.respondedAt,
  });

  final String id;
  final ChatUserSummary user;
  final String status;
  final String direction;
  final String createdAt;
  final String? respondedAt;

  factory ChatConnection.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return ChatConnection(
      id: _jsonString(json['id']),
      user: ChatUserSummary.fromJson(
        user is Map ? Map<String, dynamic>.from(user) : const {},
      ),
      status: _jsonString(json['status']),
      direction: _jsonString(json['direction']),
      createdAt: _jsonString(json['created_at']),
      respondedAt: json['responded_at'] == null
          ? null
          : _jsonString(json['responded_at']),
    );
  }

  @override
  List<Object?> get props => [id, user, status, direction, respondedAt];
}

class ChatConnectionRequests extends Equatable {
  const ChatConnectionRequests({
    this.incoming = const [],
    this.sent = const [],
  });

  final List<ChatConnection> incoming;
  final List<ChatConnection> sent;

  @override
  List<Object?> get props => [incoming, sent];
}

String _jsonString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

class ChatUserSearchResult extends Equatable {
  const ChatUserSearchResult({required this.matchedBy, this.users = const []});

  final String matchedBy;
  final List<ChatUserSummary> users;

  @override
  List<Object?> get props => [matchedBy, users];
}
