import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// The account's typing-indicator switch (Signal's rule: off means this
/// account neither shows others it is typing nor sees them typing). The
/// server enforces both halves; the client only avoids pointless frames.
///
/// Optimistically true until loaded, which is the server default — a failed
/// load must not silently switch the feature off.
class TypingIndicatorsNotifier extends Notifier<bool> {
  @override
  bool build() {
    Future.microtask(_load);
    return true;
  }

  Future<void> _load() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .get(ApiConstants.meTypingIndicators);
      state = _enabled(res.data);
    } catch (_) {}
  }

  /// Returns false when the server refused; the switch is put back.
  Future<bool> set(bool enabled) async {
    final previous = state;
    state = enabled;
    try {
      final res = await ref
          .read(apiClientProvider)
          .put(ApiConstants.meTypingIndicators, data: {'enabled': enabled});
      state = _enabled(res.data);
      return true;
    } catch (_) {
      state = previous;
      return false;
    }
  }

  static bool _enabled(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? data['enabled'] != false : true;
  }
}

final typingIndicatorsProvider =
    NotifierProvider<TypingIndicatorsNotifier, bool>(
      TypingIndicatorsNotifier.new,
    );
