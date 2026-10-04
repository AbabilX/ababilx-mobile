import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Why a link could not be saved or joined, in words for the sheet.
class GroupLinkRefused implements Exception {
  const GroupLinkRefused(this.message);
  final String message;
}

/// What somebody holding the link sees before joining (server 0167).
class GroupLinkPreview {
  const GroupLinkPreview({
    required this.conversationId,
    required this.name,
    required this.avatarUrl,
    required this.description,
    required this.memberCount,
    required this.isMember,
  });

  final String conversationId;
  final String name;
  final String avatarUrl;
  final String description;
  final int memberCount;
  final bool isMember;

  factory GroupLinkPreview.fromJson(Map<String, dynamic> json) =>
      GroupLinkPreview(
        conversationId: json['conversation_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String? ?? '',
        description: json['description'] as String? ?? '',
        memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
        isMember: json['is_member'] as bool? ?? false,
      );
}

String _linkPath(String slug) =>
    '/api/chat/group-links/${Uri.encodeComponent(slug)}';

/// A group's link as the server stored it.
typedef GroupLinkState = ({String slug, bool paused});

String _own(String conversationId) =>
    ApiConstants.independentChatConversationAction(
      conversationId,
      'public-link',
    );

GroupLinkState _state(Response<dynamic> res) {
  final data = unwrapApiData<Map<String, dynamic>>(res);
  return (
    slug: data['public_link'] as String? ?? '',
    paused: data['public_link_paused'] as bool? ?? false,
  );
}

Future<GroupLinkState> _guard(
  Future<Response<dynamic>> Function() call,
  String fallback,
) async {
  try {
    return _state(await call());
  } on DioException catch (e) {
    throw GroupLinkRefused(_reason(e, fallback: fallback));
  }
}

/// `PUT .../public-link {slug}` — admins only; a new slug once every 3 days.
Future<GroupLinkState> putGroupLink(
  ApiClient client,
  String conversationId,
  String slug,
) => _guard(
  () => client.put(_own(conversationId), data: {'slug': slug}),
  'Could not save the link.',
);

/// `PUT .../public-link {paused}` — pause or resume; the slug stays reserved.
Future<GroupLinkState> pauseGroupLink(
  ApiClient client,
  String conversationId, {
  required bool paused,
}) => _guard(
  () => client.put(_own(conversationId), data: {'paused': paused}),
  'Could not change the link.',
);

/// `DELETE .../public-link` — gone for good; the slug is free for anyone.
Future<GroupLinkState> deleteGroupLink(
  ApiClient client,
  String conversationId,
) => _guard(
  () => client.delete(_own(conversationId)),
  'Could not remove the link.',
);

/// The group behind a link, or null when no joinable group holds it — unknown,
/// deleted and private groups all answer the same.
Future<GroupLinkPreview?> fetchGroupLink(ApiClient client, String slug) async {
  try {
    final res = await client.get(_linkPath(slug));
    final data = unwrapApiData<Map<String, dynamic>>(res);
    final group = data['group'];
    if (group is! Map) return null;
    return GroupLinkPreview.fromJson(Map<String, dynamic>.from(group));
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return null;
    rethrow;
  }
}

/// Joins through the link; answers the conversation id.
Future<String> joinGroupLink(ApiClient client, String slug) async {
  try {
    final res = await client.post('${_linkPath(slug)}/join');
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return data['conversation_id'] as String? ?? '';
  } on DioException catch (e) {
    throw GroupLinkRefused(_reason(e, fallback: 'Could not join the group.'));
  }
}

String _reason(DioException e, {required String fallback}) {
  final body = e.response?.data;
  final code = body is Map ? body['error'] : null;
  return switch (code) {
    'group_link_taken' => 'That link is already taken. Try another.',
    'invalid_group_link' =>
      'Use 3–32 letters a–z, numbers, and . _ - between them.',
    'group_privacy_no_link' => 'Turn off group privacy to use a public link.',
    'group_link_not_found' => 'This group link no longer works.',
    'member_needs_secure_messages' =>
      'Set up secure messages first, then open the link again.',
    _ => fallback,
  };
}

/// " Try again on 7 Oct." from a refusal's `retry_at`, or '' without one.
String retryHint(Object? body) {
  final raw = body is Map ? body['retry_at'] : null;
  final at = raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
  if (at == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return ' Try again on ${at.day} ${months[at.month - 1]}.';
}
