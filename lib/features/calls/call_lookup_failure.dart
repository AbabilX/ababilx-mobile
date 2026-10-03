import 'dart:async';

import 'package:dio/dio.dart';

/// What a failed call lookup says about the call itself.
///
/// The three recovery paths (a CallKit record found on resume, an Accept for
/// a call this isolate never loaded, a foreground push) used to treat every
/// failure as "the call is over" and took its ringing surface down. On a
/// phone that has just woken up — radio asleep, token expired — the request
/// failing is the normal case, and it says nothing about the call.
enum CallLookupFailure {
  /// No answer about the call: timeout, no network, connection reset, DNS,
  /// 429, 5xx, or a 401 whose token refresh could not be asked. Keep the
  /// surface and ask again.
  transient,

  /// The server answered that this call does not exist.
  gone,

  /// The server refused the request outright. The surface goes, but the call
  /// is not remembered as finished — nothing was said about its state.
  rejected,

  /// 409: the row moved under the request. Read it again.
  conflict,

  /// An answer arrived and could not be read.
  malformed,
}

CallLookupFailure classifyCallLookupFailure(Object error) {
  if (error is TimeoutException) return CallLookupFailure.transient;
  // Not a transport error: the body arrived and its parsing threw.
  if (error is! DioException) return CallLookupFailure.malformed;

  final status = error.response?.statusCode;
  if (status == null) {
    return error.error is FormatException
        ? CallLookupFailure.malformed
        : CallLookupFailure.transient;
  }
  final data = error.response?.data;
  final apiError = data is Map ? data['error']?.toString() ?? '' : '';
  if (status == 404 ||
      status == 410 ||
      apiError.contains('voice_call_not_found')) {
    return CallLookupFailure.gone;
  }
  if (status == 409) return CallLookupFailure.conflict;
  // A 401 reaching a caller has already been through the client's refresh:
  // either the refresh could not be asked, which is a network problem, or the
  // session was cleared and sign-out is on its way — and that ends every call
  // by itself.
  if (status == 401 || status == 408 || status == 429 || status >= 500) {
    return CallLookupFailure.transient;
  }
  return CallLookupFailure.rejected;
}
