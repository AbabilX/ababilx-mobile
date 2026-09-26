/// Where a JPack stands, from the point of view of this phone.
enum JPackStatus {
  /// Received, not opened yet.
  unopened,

  /// Received and opened on this phone.
  opened,

  /// Ours.
  sent,
}

JPackStatus jpackStatus({required bool isOwn, required bool opened}) {
  if (isOwn) return JPackStatus.sent;
  return opened ? JPackStatus.opened : JPackStatus.unopened;
}
