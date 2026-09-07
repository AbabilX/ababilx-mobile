/// What a device does with a "somebody answered" control push.
///
/// One account rings on every signed-in device, and when one of them picks up
/// the rest have to stop. The message that says so is addressed to the
/// account — FCM cannot address a device — so it also lands on the device that
/// answered, which must ignore it. Three isolates act on that message (the
/// call provider, the foreground FCM service, and the background handler in
/// `main.dart`), and they have to agree; the rule lives here so a change lands
/// in all three at once.
enum AnsweredElsewhereAction {
  /// This device is the one holding the call. Touch nothing.
  ignore,

  /// The in-app ringing UI is up for this call: finish it properly, which
  /// stops the tone and dismisses the native surface with it.
  finishRinging,

  /// Ringing from the native surface alone — a killed or dozing app that never
  /// got a socket event, so there is no local call state to finish.
  dismissNative,
}

/// [answeredHere] is "this device answered": a live local phase in the
/// foreground, the durable mark in a background isolate that has no state.
AnsweredElsewhereAction decideAnsweredElsewhere({
  required bool answeredHere,
  required bool ringingHere,
}) {
  if (answeredHere) return AnsweredElsewhereAction.ignore;
  if (ringingHere) return AnsweredElsewhereAction.finishRinging;
  return AnsweredElsewhereAction.dismissNative;
}
