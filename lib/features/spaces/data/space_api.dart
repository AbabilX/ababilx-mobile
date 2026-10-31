import 'package:dio/dio.dart';

import 'space_backend.dart';
import 'space_message.dart';
import 'space_models.dart';

/// Spaces live in the main API (`/api/spaces/*`, SPACES.md). [dio] is the
/// app's authed Dio: it adds the JWT and refreshes on 401 itself.
class SpaceApi implements SpacesBackend {
  SpaceApi({required this.dio});

  final Dio dio;

  static String _seg(String s) => Uri.encodeComponent(s);
  static String _channel(String spaceId, String channelId) =>
      '/api/spaces/${_seg(spaceId)}/channels/${_seg(channelId)}/messages';

  /// The rail.
  @override
  Future<List<SpaceSummary>> listSpaces() async =>
      SpaceSummary.listFromJson(await _call('GET', '/api/spaces'));

  /// One Space's sidebar.
  @override
  Future<SpaceTree> channels(String spaceId) async => SpaceTree.fromJson(
    spaceId,
    await _call('GET', '/api/spaces/${_seg(spaceId)}/channels'),
  );

  /// Create; the caller becomes owner.
  @override
  Future<SpaceSummary> createSpace(String name) async =>
      _space(await _call('POST', '/api/spaces', data: {'name': name.trim()}));

  /// Join through an invite code.
  @override
  Future<SpaceSummary> joinInvite(String code) async =>
      _space(await _call('POST', '/api/spaces/join', data: {'code': code}));

  /// Newest page, or older than [before].
  @override
  Future<List<SpaceMessage>> messages(
    String spaceId,
    String channelId, {
    String? before,
  }) async => SpaceMessage.listFromJson(
    await _call(
      'GET',
      _channel(spaceId, channelId),
      query: before == null ? null : {'before': before},
    ),
  );

  /// [clientId] makes a retry idempotent on the server.
  @override
  Future<SpaceMessage> send(
    String spaceId,
    String channelId,
    String body, {
    required String clientId,
  }) async {
    final data = await _call(
      'POST',
      _channel(spaceId, channelId),
      data: {'body': body, 'client_id': clientId},
    );
    final m = SpaceMessage.fromJson(data is Map ? data['message'] : null);
    if (m == null) throw const FormatException('space: no message in answer');
    return m;
  }

  SpaceSummary _space(Object? data) {
    final raw = data is Map ? data['space'] : null;
    final s = raw is Map
        ? SpaceSummary.fromJson(Map<String, dynamic>.from(raw))
        : null;
    if (s == null) throw const FormatException('space: no space in answer');
    return s;
  }

  Future<Object?> _call(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    final r = await dio.request<Object?>(
      path,
      data: data,
      queryParameters: query,
      options: Options(method: method),
    );
    final body = r.data;
    if (body is Map && body['success'] == true) return body['data'];
    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      message: 'space: unsuccessful envelope',
    );
  }
}
