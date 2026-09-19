import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// One platform subscription shared by the DM and group call controllers.
/// CallKit's onEvent getter creates a fresh EventChannel stream on every read;
/// listening to those separately replaces the channel's message handler, and
/// cancelling either one disconnects the other. Cache the broadcast stream so
/// the platform stays subscribed until the last controller leaves.
class NativeCallEvents {
  NativeCallEvents._();

  static final Stream<CallEvent?> stream = FlutterCallkitIncoming.onEvent;
}
