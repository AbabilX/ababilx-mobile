import 'package:equatable/equatable.dart';

/// A single message in the rule's send history.
class RuleMessage extends Equatable {
  const RuleMessage({
    required this.id,
    required this.ruleId,
    required this.userId,
    required this.content,
    required this.channelId,
    required this.sentAt,
    this.slackTs,
    this.noteUsed = '',
  });

  final String id;
  final String ruleId;
  final String userId;
  final String content;
  final String channelId;
  final DateTime sentAt;
  final String? slackTs;
  final String noteUsed;

  factory RuleMessage.fromJson(Map<String, dynamic> json) => RuleMessage(
        id: json['id'] as String? ?? '',
        ruleId: json['rule_id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        content: json['content'] as String? ?? '',
        channelId: json['channel_id'] as String? ?? '',
        sentAt: json['sent_at'] != null
            ? DateTime.parse(json['sent_at'] as String)
            : DateTime.now(),
        slackTs: json['slack_ts'] as String?,
        noteUsed: json['note_used'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id];
}

class SlackChannel extends Equatable {
  const SlackChannel({required this.id, required this.name});

  final String id;
  final String name;

  factory SlackChannel.fromJson(Map<String, dynamic> json) => SlackChannel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id];

  @override
  String toString() => '#$name';
}
