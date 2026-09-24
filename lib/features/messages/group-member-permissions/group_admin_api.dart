import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../data/models/chat_models.dart';

/// Group member permissions, tags and group pins (server migration 0157).
/// Every route is under `/api/chat/conversations/:id/…`; the server decides
/// who may call each one (`services/chat/access_member_perms.go`).

String _action(String conversationId, String path) =>
    ApiConstants.independentChatConversationAction(conversationId, path);

/// `PUT …/permissions {defaults}` — what every member may do. Admins only.
/// Answers with the updated conversation row.
Future<ChatConversation> putGroupDefaultPermissions(
  ApiClient client,
  String conversationId,
  GroupMemberPerms defaults,
) async {
  final res = await client.put(
    _action(conversationId, 'permissions'),
    data: {'defaults': defaults.toJson()},
  );
  return ChatConversation.fromJson(unwrapApiData<Map<String, dynamic>>(res));
}

/// The result of one member's exception write: what they may now do.
class MemberPermissionsResult {
  const MemberPermissionsResult(this.permissions, this.restricted);

  final GroupMemberPerms permissions;
  final bool restricted;
}

/// `PUT …/members/:userId/permissions` — the whole set of what this member
/// may do. The server stores only what is off, so a switch the group already
/// has off stays off whatever is sent.
Future<MemberPermissionsResult> putMemberPermissions(
  ApiClient client,
  String conversationId,
  String userId,
  GroupMemberPerms permissions,
) async {
  final res = await client.put(
    _action(conversationId, 'members/$userId/permissions'),
    data: permissions.toJson(),
  );
  final data = unwrapApiData<Map<String, dynamic>>(res);
  return MemberPermissionsResult(
    GroupMemberPerms.maybeFromJson(data['permissions']) ?? permissions,
    data['restricted'] == true,
  );
}

/// `PUT …/members/:userId/tag` — "" clears. Answers with the tag as the
/// server stored it (trimmed, invisibles dropped).
Future<String> putMemberTag(
  ApiClient client,
  String conversationId,
  String userId,
  String tag,
) async {
  final res = await client.put(
    _action(conversationId, 'members/$userId/tag'),
    data: {'tag': tag},
  );
  return unwrapApiData<Map<String, dynamic>>(res)['tag'] as String? ?? '';
}

/// One pin every member sees.
class GroupPin {
  const GroupPin({
    required this.message,
    required this.pinnedAt,
    this.pinnedBy = '',
  });

  final ChatMessage message;
  final String pinnedAt;
  final String pinnedBy;

  factory GroupPin.fromJson(Map<String, dynamic> json) => GroupPin(
    message: ChatMessage.fromJson(json['message'] as Map<String, dynamic>),
    pinnedAt: json['pinned_at'] as String? ?? '',
    pinnedBy: json['pinned_by'] as String? ?? '',
  );

  GroupPin withMessage(ChatMessage next) =>
      GroupPin(message: next, pinnedAt: pinnedAt, pinnedBy: pinnedBy);
}

class GroupPinsPage {
  const GroupPinsPage({this.pins = const [], this.canPin = false});

  final List<GroupPin> pins;
  final bool canPin;
}

/// `GET …/group-pins` — newest first, as this viewer may see them.
Future<GroupPinsPage> listGroupPins(
  ApiClient client,
  String conversationId,
) async {
  final res = await client.get(_action(conversationId, 'group-pins'));
  final data = unwrapApiData<Map<String, dynamic>>(res);
  final raw = data['pins'] as List<dynamic>? ?? const [];
  return GroupPinsPage(
    pins: raw
        .whereType<Map>()
        .map((e) => GroupPin.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    canPin: data['can_pin'] == true,
  );
}

Future<void> putGroupPin(
  ApiClient client,
  String conversationId,
  String messageId,
) => client.put(_action(conversationId, 'group-pins/$messageId'));

Future<void> deleteGroupPin(
  ApiClient client,
  String conversationId,
  String messageId,
) => client.delete(_action(conversationId, 'group-pins/$messageId'));

/// What to send for one member: their own choices, with every switch the
/// GROUP has off sent as on. Those rows are locked on screen; sending them off
/// would store a personal restriction nobody chose, which would outlive the
/// group turning that permission back on.
GroupMemberPerms memberExceptionOnly(
  GroupMemberPerms mine,
  GroupMemberPerms group,
) {
  final m = mine.toJson();
  final g = group.toJson();
  return GroupMemberPerms.fromJson({
    for (final key in m.keys) key: m[key] == true || g[key] != true,
  });
}
