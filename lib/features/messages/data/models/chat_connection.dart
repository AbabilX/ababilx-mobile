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
  });

  final String userId;
  final String name;
  final String username;
  final String avatarUrl;
  final String connection;
  final bool sharedWorkspace;
  final bool canMessage;

  factory ChatUserSummary.fromJson(Map<String, dynamic> json) =>
      ChatUserSummary(
        userId: json['user_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        username: json['username'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String? ?? '',
        connection: json['connection'] as String? ?? 'none',
        sharedWorkspace: json['shared_workspace'] as bool? ?? false,
        canMessage: json['can_message'] as bool? ?? false,
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

  factory ChatConnection.fromJson(Map<String, dynamic> json) => ChatConnection(
    id: json['id'] as String? ?? '',
    user: ChatUserSummary.fromJson(
      Map<String, dynamic>.from(json['user'] as Map? ?? const {}),
    ),
    status: json['status'] as String? ?? '',
    direction: json['direction'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    respondedAt: json['responded_at'] as String?,
  );

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

class ChatUserSearchResult extends Equatable {
  const ChatUserSearchResult({required this.matchedBy, this.users = const []});

  final String matchedBy;
  final List<ChatUserSummary> users;

  @override
  List<Object?> get props => [matchedBy, users];
}
