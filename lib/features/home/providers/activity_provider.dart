import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/activity_repository.dart';

class ActivityNotifier extends AsyncNotifier<ActivityData> {
  String _period = 'weekly';

  @override
  Future<ActivityData> build() => _fetch();

  Future<ActivityData> _fetch() =>
      ref.read(activityRepositoryProvider).getActivity(period: _period);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> setPeriod(String period) async {
    if (_period == period) return;
    _period = period;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final activityProvider =
    AsyncNotifierProvider<ActivityNotifier, ActivityData>(ActivityNotifier.new);
