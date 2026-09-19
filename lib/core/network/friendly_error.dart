import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../features/messages/chat-empty-state/index.dart';

/// True when [error] looks like "no network", not a real server/app failure
/// — Dio's connection/timeout error types, and the raw socket errors they
/// wrap on a dead connection.
bool isOfflineError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      default:
        return false;
    }
  }
  return false;
}

/// A title/subtitle safe to show a user for a failed load — never a raw
/// exception dump. Offline gets a specific, actionable message (it's the
/// one thing the user can fix themselves); anything else gets a calm,
/// generic fallback rather than surfacing server/internal detail.
({String title, String subtitle, IconData icon}) describeLoadError(
  Object error,
) {
  if (isOfflineError(error)) {
    return (
      title: 'No internet connection',
      subtitle: 'Please turn on your internet and try again.',
      icon: Icons.wifi_off_rounded,
    );
  }
  return (
    title: 'Something went wrong',
    subtitle: 'Pull to refresh or try again shortly.',
    icon: Icons.error_outline,
  );
}

/// [describeLoadError] flattened to one line, for single-line error slots
/// (a `Text` widget, a `SnackBar`) that only take a message, not a title.
String friendlyErrorMessage(Object error) {
  final copy = describeLoadError(error);
  return '${copy.title}. ${copy.subtitle}';
}

/// People → Connections hits `/api/chat/connections`, which is behind the
/// server policy gate. A cached profile can look accepted while the API still
/// answers 403 — show that instead of a generic failure.
bool isPolicyNotAcceptedError(Object error) =>
    serverErrorCode(error) == 'policy_not_accepted';

String chatConnectionsLoadError(Object error) {
  if (isPolicyNotAcceptedError(error)) {
    return 'Accept the privacy policy to load your connections.';
  }
  return friendlyErrorMessage(error);
}

/// The machine-readable code from a structured API failure
/// (`{success: false, error: "...", ...}`), or null when the failure was a
/// transport problem rather than a considered answer from the server.
String? serverErrorCode(Object error) => _errorField(error, 'error');

/// The human sentence the API deliberately attached to a failure.
///
/// Only `message` is read, never `error`: the code field is often a raw
/// `err.Error()` and would leak internals, whereas `message` is only ever set
/// by a handler that meant it for a person.
String? serverErrorMessage(Object error) => _errorField(error, 'message');

String? _errorField(Object error, String key) {
  if (error is! DioException) return null;
  final data = error.response?.data;
  if (data is! Map) return null;
  final value = data[key];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// [describeLoadError] as a ready-to-render widget, for the very common
/// `error: (error, _) => LoadErrorState(error)` case.
class LoadErrorState extends StatelessWidget {
  const LoadErrorState(this.error, {super.key});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final copy = describeLoadError(error);
    return ChatEmptyState(
      title: copy.title,
      subtitle: copy.subtitle,
      icon: copy.icon,
    );
  }
}
