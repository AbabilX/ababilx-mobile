import 'package:equatable/equatable.dart';

/// Mirrors the backend Rule struct exactly.
class RepoTarget extends Equatable {
  const RepoTarget({required this.repoFullName, required this.branch});

  final String repoFullName;
  final String branch;

  factory RepoTarget.fromJson(Map<String, dynamic> json) => RepoTarget(
        repoFullName: json['repo_full_name'] as String? ?? '',
        branch: json['branch'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'repo_full_name': repoFullName,
        'branch': branch,
      };

  @override
  List<Object?> get props => [repoFullName, branch];
}

class Rule extends Equatable {
  const Rule({
    required this.id,
    required this.userId,
    required this.name,
    required this.channelId,
    required this.channelName,
    required this.sendTime,
    required this.timezone,
    required this.daysOfWeek,
    required this.isActive,
    this.lastSentAt,
    required this.runMode,
    this.targetDate,
    this.repoTargets = const [],
    required this.threadEnabled,
    this.threadStyle,
    required this.postWhenEmpty,
    this.note = '',
    this.exampleMessage = '',
    this.notificationMinutes,
    this.notificationSentAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String channelId;
  final String channelName;
  final String sendTime; // "HH:MM"
  final String timezone;
  final List<int> daysOfWeek;
  final bool isActive;
  final DateTime? lastSentAt;
  final String runMode; // "loop" | "once"
  final String? targetDate; // "YYYY-MM-DD"
  final List<RepoTarget> repoTargets;
  final bool threadEnabled;
  final String? threadStyle;
  final bool postWhenEmpty;
  final String note;
  final String exampleMessage;
  final int? notificationMinutes; // null = no notification
  final DateTime? notificationSentAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Rule.fromJson(Map<String, dynamic> json) {
    List<int> parseDays(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => int.parse(e.toString())).toList();
      if (v is String) {
        return v
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList();
      }
      return [];
    }

    List<RepoTarget> parseRepos(dynamic v) {
      if (v == null) return [];
      if (v is List) {
        return v
            .map((e) => RepoTarget.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    return Rule(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      channelId: json['channel_id'] as String? ?? '',
      channelName: json['channel_name'] as String? ?? '',
      sendTime: json['send_time'] as String? ?? '09:00',
      timezone: json['timezone'] as String? ?? 'UTC',
      daysOfWeek: parseDays(json['days_of_week']),
      isActive: json['is_active'] as bool? ?? true,
      lastSentAt: json['last_sent_at'] != null
          ? DateTime.tryParse(json['last_sent_at'] as String)
          : null,
      runMode: json['run_mode'] as String? ?? 'loop',
      targetDate: json['target_date'] as String?,
      repoTargets: parseRepos(json['repo_targets'] ?? json['repos']),
      threadEnabled: json['thread_enabled'] as bool? ?? false,
      threadStyle: json['thread_style'] as String?,
      postWhenEmpty: json['post_when_empty'] as bool? ?? false,
      note: json['note'] as String? ?? '',
      exampleMessage: json['example_message'] as String? ?? '',
      notificationMinutes: json['notification_minutes'] as int?,
      notificationSentAt: json['notification_sent_at'] != null
          ? DateTime.tryParse(json['notification_sent_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'channel_id': channelId,
        'channel_name': channelName,
        'send_time': sendTime,
        'timezone': timezone,
        'days_of_week': daysOfWeek,
        'is_active': isActive,
        'run_mode': runMode,
        if (targetDate != null) 'target_date': targetDate,
        'repos': repoTargets.map((r) => r.toJson()).toList(),
        'thread_enabled': threadEnabled,
        if (threadStyle != null) 'thread_style': threadStyle,
        'post_when_empty': postWhenEmpty,
        'note': note,
        'example_message': exampleMessage,
        if (notificationMinutes != null)
          'notification_minutes': notificationMinutes,
      };

  Rule copyWith({
    String? name,
    String? channelId,
    String? channelName,
    String? sendTime,
    String? timezone,
    List<int>? daysOfWeek,
    bool? isActive,
    String? runMode,
    String? targetDate,
    List<RepoTarget>? repoTargets,
    bool? threadEnabled,
    String? threadStyle,
    bool? postWhenEmpty,
    String? note,
    String? exampleMessage,
    int? notificationMinutes,
    bool clearNotificationMinutes = false,
  }) =>
      Rule(
        id: id,
        userId: userId,
        name: name ?? this.name,
        channelId: channelId ?? this.channelId,
        channelName: channelName ?? this.channelName,
        sendTime: sendTime ?? this.sendTime,
        timezone: timezone ?? this.timezone,
        daysOfWeek: daysOfWeek ?? this.daysOfWeek,
        isActive: isActive ?? this.isActive,
        lastSentAt: lastSentAt,
        runMode: runMode ?? this.runMode,
        targetDate: targetDate ?? this.targetDate,
        repoTargets: repoTargets ?? this.repoTargets,
        threadEnabled: threadEnabled ?? this.threadEnabled,
        threadStyle: threadStyle ?? this.threadStyle,
        postWhenEmpty: postWhenEmpty ?? this.postWhenEmpty,
        note: note ?? this.note,
        exampleMessage: exampleMessage ?? this.exampleMessage,
        notificationMinutes: clearNotificationMinutes
            ? null
            : (notificationMinutes ?? this.notificationMinutes),
        notificationSentAt: notificationSentAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  List<Object?> get props => [id, name, isActive, updatedAt];
}
