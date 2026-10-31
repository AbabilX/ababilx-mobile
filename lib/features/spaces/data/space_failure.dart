import 'package:dio/dio.dart';

/// Why a Spaces request failed, in the terms the screen speaks.
enum SpaceFailure {
  /// No network, or no answer in time.
  offline,

  /// The Space service is down, not deployed, or answered 404/5xx.
  unavailable,

  /// The token could not be refreshed: the main session is gone.
  signedOut,

  /// Not allowed (private channel, banned, removed).
  forbidden,

  /// Rate limited; try again shortly.
  busy,

  unknown,
}

/// Thrown when there is no Space service to ask (token route 503, no URL).
class SpaceUnavailable implements Exception {
  const SpaceUnavailable();
}

SpaceFailure classifySpaceError(Object error) {
  if (error is SpaceUnavailable) return SpaceFailure.unavailable;
  if (error is! DioException) return SpaceFailure.unknown;
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return SpaceFailure.offline;
    default:
  }
  final code = error.response?.statusCode;
  if (code == null) return SpaceFailure.unknown;
  if (code == 401) return SpaceFailure.signedOut;
  if (code == 403) return SpaceFailure.forbidden;
  if (code == 429) return SpaceFailure.busy;
  if (code == 404 || code >= 500) return SpaceFailure.unavailable;
  return SpaceFailure.unknown;
}

/// Calm, user-safe words for a failure. Never the raw error.
({String title, String subtitle}) spaceFailureCopy(
  SpaceFailure f,
) => switch (f) {
  // "Offline" also covers an unreachable Space service (DNS, refused),
  // which looks the same from here — so do not claim the phone is offline.
  SpaceFailure.offline => (
    title: "Can't reach Spaces",
    subtitle:
        'Check your internet connection. Your chats and calls are not affected.',
  ),
  SpaceFailure.unavailable => (
    title: 'Spaces is unavailable right now',
    subtitle: 'Your chats and calls are not affected. Try again in a bit.',
  ),
  SpaceFailure.signedOut => (
    title: 'Could not sign in to Spaces',
    subtitle: 'Open the app again or sign in again.',
  ),
  SpaceFailure.forbidden => (
    title: 'You do not have access',
    subtitle: 'You may have been removed, or this channel is private.',
  ),
  SpaceFailure.busy => (
    title: 'Too many requests',
    subtitle: 'Wait a moment and try again.',
  ),
  SpaceFailure.unknown => (
    title: 'Something went wrong',
    subtitle: 'Try again shortly.',
  ),
};
