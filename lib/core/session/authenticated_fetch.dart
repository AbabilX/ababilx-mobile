import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Runs [fetch] only after auth is resolved and the user is logged in.
/// Before login, skips the API call and refreshes when auth becomes true.
Future<T> fetchWhenAuthenticated<T>(
  Ref ref,
  Future<T> Function() fetch,
) async {
  final isLoggedIn = await ref.watch(authProvider.future);
  if (!isLoggedIn) {
    ref.listen(authProvider, (previous, next) {
      final wasLoggedIn = previous?.valueOrNull ?? false;
      if (!wasLoggedIn && (next.valueOrNull ?? false)) {
        ref.invalidateSelf();
      }
    });
    throw StateError('Not authenticated');
  }

  return fetch();
}
