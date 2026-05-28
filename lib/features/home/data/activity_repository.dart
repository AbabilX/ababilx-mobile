import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';

class ActivityDay {
  const ActivityDay({required this.day, required this.standups, required this.commits});
  final int day;       // weekly: 0=Sun…6=Sat | monthly: 1-31
  final int standups;
  final int commits;

  int get total => standups + commits;

  factory ActivityDay.fromJson(Map<String, dynamic> json) => ActivityDay(
        day: json['day'] as int? ?? 0,
        standups: json['standups'] as int? ?? 0,
        commits: json['commits'] as int? ?? 0,
      );
}

class ActivityData {
  const ActivityData({
    required this.period,
    required this.days,
    required this.today,
    required this.daysInMonth,
    required this.totalStandups,
    required this.totalCommits,
  });

  final String period;           // 'weekly' | 'monthly'
  final List<ActivityDay> days;
  final int today;               // weekly: 0-6 dow | monthly: 1-31 dom
  final int daysInMonth;
  final int totalStandups;
  final int totalCommits;

  int get totalThisWeek => totalStandups + totalCommits;
  bool get isMonthly => period == 'monthly';

  factory ActivityData.empty() => ActivityData(
        period: 'weekly',
        days: List.generate(7, (i) => ActivityDay(day: i, standups: 0, commits: 0)),
        today: () {
          final d = DateTime.now().weekday;
          return d == 7 ? 0 : d;
        }(),
        daysInMonth: 0,
        totalStandups: 0,
        totalCommits: 0,
      );

  factory ActivityData.fromJson(Map<String, dynamic> data) {
    final daysList = data['days'] as List? ?? [];
    return ActivityData(
      period: data['period'] as String? ?? 'weekly',
      days: daysList.map((e) => ActivityDay.fromJson(e as Map<String, dynamic>)).toList(),
      today: data['today'] as int? ?? 0,
      daysInMonth: data['days_in_month'] as int? ?? 0,
      totalStandups: data['total_standups'] as int? ?? 0,
      totalCommits: data['total_commits'] as int? ?? 0,
    );
  }
}

class ActivityRepository {
  const ActivityRepository(this._client);
  final ApiClient _client;

  Future<ActivityData> getActivity({String period = 'weekly'}) async {
    final res = await _client.get(
      ApiConstants.weeklyActivity,
      queryParameters: {'period': period},
    );
    final raw = res.data;
    final data = (raw is Map<String, dynamic> && raw.containsKey('data'))
        ? raw['data'] as Map<String, dynamic>
        : raw as Map<String, dynamic>;
    return ActivityData.fromJson(data);
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(apiClientProvider)),
);
