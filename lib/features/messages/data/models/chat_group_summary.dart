import 'package:equatable/equatable.dart';

/// A group as it appears on someone else's profile — enough to draw a row and
/// open it, nothing more.
class ChatGroupSummary extends Equatable {
  const ChatGroupSummary({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.memberCount,
    required this.scope,
    required this.type,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final int memberCount;
  final String scope;
  final String type;

  factory ChatGroupSummary.fromJson(Map<String, dynamic> json) =>
      ChatGroupSummary(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String? ?? '',
        memberCount: json['member_count'] as int? ?? 0,
        scope: json['scope'] as String? ?? '',
        type: json['type'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, name, avatarUrl, memberCount];
}

/// Both halves of the "groups in common" block: what the two people already
/// share, and what the viewer could add them to.
///
/// [canAdd] is a hint for drawing the picker, never the permission itself —
/// the add call is still refused server-side if the group or the relationship
/// says no.
class ChatGroupsInCommon extends Equatable {
  const ChatGroupsInCommon({required this.inCommon, required this.canAdd});

  const ChatGroupsInCommon.empty() : inCommon = const [], canAdd = const [];

  final List<ChatGroupSummary> inCommon;
  final List<ChatGroupSummary> canAdd;

  factory ChatGroupsInCommon.fromJson(Map<String, dynamic> json) =>
      ChatGroupsInCommon(
        inCommon: _list(json['in_common']),
        canAdd: _list(json['can_add']),
      );

  static List<ChatGroupSummary> _list(dynamic raw) => (raw as List? ?? [])
      .map((e) => ChatGroupSummary.fromJson(e as Map<String, dynamic>))
      .toList();

  @override
  List<Object?> get props => [inCommon, canAdd];
}
