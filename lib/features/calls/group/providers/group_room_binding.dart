import 'package:livekit_client/livekit_client.dart';

/// Wires snapshot syncing onto a connected [Room] and returns the detach hook —
/// the mobile counterpart of web `group-room-events.ts`.
///
/// Remote audio needs no manual attachment here: native WebRTC renders
/// subscribed audio tracks itself, so only the visible state has to be synced.
class GroupRoomBinding {
  GroupRoomBinding._(this._room, this._sync, this._listener);

  final Room _room;
  final void Function() _sync;
  final EventsListener<RoomEvent> _listener;

  static GroupRoomBinding attach(
    Room room, {
    required void Function() sync,
    required void Function() onDisconnected,
    required void Function(TrackSource source) onLocalTrackUnpublished,
  }) {
    final listener = room.createListener();
    final binding = GroupRoomBinding._(room, sync, listener);

    // Room is a ChangeNotifier — it fires for joins, leaves, mutes, speaking
    // changes and track updates, which is exactly the web `syncedEvents` set.
    room.addListener(sync);

    listener
      ..on<RoomDisconnectedEvent>((_) => onDisconnected())
      ..on<LocalTrackUnpublishedEvent>(
        (event) => onLocalTrackUnpublished(event.publication.source),
      )
      ..on<TrackSubscribedEvent>((_) => sync())
      ..on<TrackUnsubscribedEvent>((_) => sync())
      ..on<ActiveSpeakersChangedEvent>((_) => sync());

    return binding;
  }

  Future<void> detach() async {
    _room.removeListener(_sync);
    await _listener.dispose();
  }
}
