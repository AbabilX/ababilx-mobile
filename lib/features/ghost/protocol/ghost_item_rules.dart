/// How long a Ghost Chat photo lives on the other phone once it is opened.
///
/// The sender picks it per photo. The receiver never sees a timed photo in the
/// list: it arrives as "Tap to view", the countdown starts when it is opened,
/// and when it runs out both phones zero the bytes (`viewed` frame).
enum GhostViewTimer {
  off(null),
  once('once'),
  s5(5),
  s10(10),
  s30(30);

  const GhostViewTimer(this.wire);

  /// `"once"`, a number of seconds, or null for no timer (field omitted).
  final Object? wire;

  bool get timed => this != off;

  /// Null for [off] and [once] — once closes when the viewer is closed.
  Duration? get duration => switch (this) {
    s5 => const Duration(seconds: 5),
    s10 => const Duration(seconds: 10),
    s30 => const Duration(seconds: 30),
    _ => null,
  };

  /// A missing field is [off]. Anything present but unknown — a newer peer's
  /// value, or garbage — is [once]: the sender asked for SOME limit, and the
  /// strictest one is the only safe reading of a limit we do not understand.
  static GhostViewTimer decode(Object? raw) {
    if (raw == null) return off;
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    return once;
  }
}

/// What the sender allows for one photo or file.
///
/// [allowSave] off (the default) means the receiver may only look: photos,
/// PDFs and videos open inside Ghost Chat, from memory, and nothing else opens
/// at all — handing a file to another app is handing it a copy. On, the
/// receiver gets Save and may open it elsewhere.
///
/// The timer is photo-only, and a timed photo can never be saved: a saved copy
/// would outlive the timer it was sent with.
class GhostItemRules {
  const GhostItemRules({
    this.timer = GhostViewTimer.off,
    bool allowSave = false,
  }) : allowSave = allowSave && timer == GhostViewTimer.off;

  final GhostViewTimer timer;
  final bool allowSave;

  static const none = GhostItemRules();

  GhostItemRules withTimer(GhostViewTimer next) =>
      GhostItemRules(timer: next, allowSave: allowSave);

  GhostItemRules withSave(bool next) =>
      GhostItemRules(timer: timer, allowSave: next);
}
