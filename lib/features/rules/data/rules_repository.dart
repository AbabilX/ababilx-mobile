import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import 'models/rule.dart';
import 'models/rule_message.dart';

class RulesRepository {
  const RulesRepository(this._client);
  final ApiClient _client;

  /// GET /api/rules
  Future<List<Rule>> getRules() async {
    final res = await _client.get(ApiConstants.rules);
    final data = _extractData(res.data);
    if (data is List) {
      return data
          .map((e) => Rule.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// POST /api/rules
  Future<Rule> createRule(Map<String, dynamic> body) async {
    final res = await _client.post(ApiConstants.rules, data: body);
    return Rule.fromJson(_extractData(res.data) as Map<String, dynamic>);
  }

  /// PUT /api/rules/:id
  Future<Rule> updateRule(String id, Map<String, dynamic> body) async {
    final res = await _client.put(ApiConstants.ruleById(id), data: body);
    return Rule.fromJson(_extractData(res.data) as Map<String, dynamic>);
  }

  /// DELETE /api/rules/:id
  Future<void> deleteRule(String id) async {
    await _client.delete(ApiConstants.ruleById(id));
  }

  /// POST /api/rules/:id/preview → AI-generated preview message
  Future<String> previewRule(String id) async {
    final res = await _client.post(ApiConstants.rulePreview(id));
    final data = _extractData(res.data);
    if (data is Map) {
      return data['message'] as String? ??
          data['content'] as String? ??
          data.toString();
    }
    return data.toString();
  }

  /// POST /api/rules/:id/trigger — send now (optionally with override message)
  Future<void> triggerRule(String id, {String? message}) async {
    await _client.post(
      ApiConstants.ruleTrigger(id),
      data: message != null ? {'message': message} : null,
    );
  }

  /// POST /api/rules/:id/override-message — store one-off edit in Redis
  Future<void> overrideMessage(String id, String content) async {
    await _client.post(
      ApiConstants.ruleOverride(id),
      data: {'content': content},
    );
  }

  /// GET /api/rules/:id/messages
  Future<List<RuleMessage>> getRuleMessages(String id,
      {int page = 1}) async {
    final res = await _client.get(
      ApiConstants.ruleMessages(id),
      queryParameters: {'page': page, 'limit': 20},
    );
    final data = _extractData(res.data);
    if (data is List) {
      return data
          .map((e) => RuleMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// DELETE /api/rules/:ruleId/messages/:msgId
  Future<void> deleteRuleMessage(String ruleId, String msgId) async {
    await _client.delete(ApiConstants.ruleMessageById(ruleId, msgId));
  }

  /// GET /api/slack/channels
  Future<List<SlackChannel>> getSlackChannels() async {
    final res = await _client.get(ApiConstants.slackChannels);
    final data = _extractData(res.data);
    if (data is List) {
      return data
          .map((e) => SlackChannel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  dynamic _extractData(dynamic responseData) {
    if (responseData is Map<String, dynamic> &&
        responseData.containsKey('data')) {
      return responseData['data'];
    }
    return responseData;
  }
}

final rulesRepositoryProvider = Provider<RulesRepository>(
  (ref) => RulesRepository(ref.watch(apiClientProvider)),
);
