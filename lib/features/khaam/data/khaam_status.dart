/// Where a Khaam stands, from the point of view of this phone.
enum KhaamStatus {
  /// Received, not opened yet.
  unopened,

  /// Received and opened on this phone.
  opened,

  /// Ours.
  sent,
}

KhaamStatus khaamStatus({required bool isOwn, required bool opened}) {
  if (isOwn) return KhaamStatus.sent;
  return opened ? KhaamStatus.opened : KhaamStatus.unopened;
}
