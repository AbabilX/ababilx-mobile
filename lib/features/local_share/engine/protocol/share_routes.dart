/// HTTP surface of `abx-share/1` (LOCAL_SHARE_PROTOCOL.md).
abstract final class ShareRoutes {
  static const info = '/abx/v1/info';
  static const pair = '/abx/v1/pair';
  static const messages = '/abx/v1/messages';
  static const filesPrefix = '/abx/v1/files/';

  static String file(String messageId, String fileId, int offset) =>
      '$filesPrefix$messageId/$fileId?offset=$offset';

  static String cancel(String messageId) => '$messages/$messageId/cancel';

  static const deviceHeader = 'x-abx-device';
}

/// Body ceilings. A pair or envelope request is JSON and small; anything
/// bigger is not a client of this protocol.
abstract final class ShareLimits {
  static const pairBodyBytes = 8 * 1024;
  static const envelopeBodyBytes = 4 * 1024 * 1024;
  static const pairAnswerTimeout = Duration(seconds: 60);
  static const maxPendingPairs = 3;

  /// No bytes for this long ends a transfer attempt; the bytes received stay
  /// on disk and the next attempt resumes from them.
  static const idleTimeout = Duration(seconds: 30);

  /// Files below this size travel three at a time.
  static const smallFileBytes = 8 * 1024 * 1024;
  static const smallFileParallelism = 3;
}
