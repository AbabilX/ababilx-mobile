import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/rule.dart';

/// Controlled form state for create/edit rule.
class RuleFormState {
  const RuleFormState({
    this.name = '',
    this.channelId = '',
    this.channelName = '',
    this.sendTime = '09:00',
    this.timezone = 'UTC',
    this.daysOfWeek = const [1, 2, 3, 4, 5], // Mon–Fri default
    this.runMode = 'loop',
    this.targetDate,
    this.repoTargets = const [],
    this.exampleMessage = '',
    this.postWhenEmpty = false,
    this.threadEnabled = false,
    this.note = '',
    this.notificationMinutes = 15,
    this.isActive = true,
    this.isSaving = false,
    this.error,
  });

  final String name;
  final String channelId;
  final String channelName;
  final String sendTime;
  final String timezone;
  final List<int> daysOfWeek;
  final String runMode;
  final String? targetDate;
  final List<RepoTarget> repoTargets;
  final String exampleMessage;
  final bool postWhenEmpty;
  final bool threadEnabled;
  final String note;
  final int? notificationMinutes; // null = disabled
  final bool isActive;
  final bool isSaving;
  final String? error;

  RuleFormState copyWith({
    String? name,
    String? channelId,
    String? channelName,
    String? sendTime,
    String? timezone,
    List<int>? daysOfWeek,
    String? runMode,
    String? targetDate,
    List<RepoTarget>? repoTargets,
    String? exampleMessage,
    bool? postWhenEmpty,
    bool? threadEnabled,
    String? note,
    int? notificationMinutes,
    bool clearNotificationMinutes = false,
    bool? isActive,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) =>
      RuleFormState(
        name: name ?? this.name,
        channelId: channelId ?? this.channelId,
        channelName: channelName ?? this.channelName,
        sendTime: sendTime ?? this.sendTime,
        timezone: timezone ?? this.timezone,
        daysOfWeek: daysOfWeek ?? this.daysOfWeek,
        runMode: runMode ?? this.runMode,
        targetDate: targetDate ?? this.targetDate,
        repoTargets: repoTargets ?? this.repoTargets,
        exampleMessage: exampleMessage ?? this.exampleMessage,
        postWhenEmpty: postWhenEmpty ?? this.postWhenEmpty,
        threadEnabled: threadEnabled ?? this.threadEnabled,
        note: note ?? this.note,
        notificationMinutes: clearNotificationMinutes
            ? null
            : (notificationMinutes ?? this.notificationMinutes),
        isActive: isActive ?? this.isActive,
        isSaving: isSaving ?? this.isSaving,
        error: clearError ? null : (error ?? this.error),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'channel_id': channelId,
        'channel_name': channelName,
        'send_time': sendTime,
        'timezone': timezone,
        'days_of_week': daysOfWeek,
        'run_mode': runMode,
        if (targetDate != null) 'target_date': targetDate,
        'repos': repoTargets.map((r) => r.toJson()).toList(),
        'example_message': exampleMessage,
        'post_when_empty': postWhenEmpty,
        'thread_enabled': threadEnabled,
        'note': note,
        if (notificationMinutes != null)
          'notification_minutes': notificationMinutes,
        'is_active': isActive,
      };

  bool get isValid =>
      name.isNotEmpty && channelId.isNotEmpty && daysOfWeek.isNotEmpty;
}

class RuleFormNotifier extends Notifier<RuleFormState> {
  @override
  RuleFormState build() => const RuleFormState();

  void init([Rule? existing]) {
    if (existing == null) {
      state = const RuleFormState();
    } else {
      state = RuleFormState(
        name: existing.name,
        channelId: existing.channelId,
        channelName: existing.channelName,
        sendTime: existing.sendTime,
        timezone: existing.timezone,
        daysOfWeek: existing.daysOfWeek,
        runMode: existing.runMode,
        targetDate: existing.targetDate,
        repoTargets: existing.repoTargets,
        exampleMessage: existing.exampleMessage,
        postWhenEmpty: existing.postWhenEmpty,
        threadEnabled: existing.threadEnabled,
        note: existing.note,
        notificationMinutes: existing.notificationMinutes,
        isActive: existing.isActive,
      );
    }
  }

  void setName(String v) => state = state.copyWith(name: v, clearError: true);
  void setChannel(String id, String name) =>
      state = state.copyWith(channelId: id, channelName: name);
  void setSendTime(String v) => state = state.copyWith(sendTime: v);
  void setTimezone(String v) => state = state.copyWith(timezone: v);
  void setDaysOfWeek(List<int> v) => state = state.copyWith(daysOfWeek: v);
  void toggleDay(int day) {
    final days = List<int>.from(state.daysOfWeek);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      days.add(day);
      days.sort();
    }
    state = state.copyWith(daysOfWeek: days);
  }

  void setRunMode(String v) => state = state.copyWith(runMode: v);
  void setTargetDate(String? v) => state = state.copyWith(targetDate: v);
  void setExampleMessage(String v) =>
      state = state.copyWith(exampleMessage: v);
  void setPostWhenEmpty(bool v) => state = state.copyWith(postWhenEmpty: v);
  void setThreadEnabled(bool v) => state = state.copyWith(threadEnabled: v);
  void setNote(String v) => state = state.copyWith(note: v);
  void setNotificationMinutes(int? v) => v == null
      ? state = state.copyWith(clearNotificationMinutes: true)
      : state = state.copyWith(notificationMinutes: v);
  void setIsActive(bool v) => state = state.copyWith(isActive: v);
  void addRepoTarget(RepoTarget r) =>
      state = state.copyWith(repoTargets: [...state.repoTargets, r]);
  void removeRepoTarget(int idx) {
    final repos = List<RepoTarget>.from(state.repoTargets)..removeAt(idx);
    state = state.copyWith(repoTargets: repos);
  }

  void setSaving(bool v) => state = state.copyWith(isSaving: v);
  void setError(String? v) => state = state.copyWith(error: v);
}

final ruleFormProvider =
    NotifierProvider<RuleFormNotifier, RuleFormState>(RuleFormNotifier.new);
