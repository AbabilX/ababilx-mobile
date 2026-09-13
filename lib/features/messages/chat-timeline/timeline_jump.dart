import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Walking the timeline back to a message somebody answered.
///
/// A tap on a quote has to reach a message that is usually not built — a
/// `ListView.builder` only holds what is on screen — and whose height nothing
/// knows in advance, so there is no offset to scroll to. What there is, is a
/// direction: a quoted message is always OLDER than the reply, which in this
/// reversed list means a LARGER scroll offset. So the list is walked back a
/// screen at a time, asking for the page before the oldest one loaded whenever
/// it runs out, until the row builds and registers its key here.
///
/// The walk jumps rather than animates — a smooth scroll per screen turns a
/// month of history into a ten-second ride — and only the last hop, onto the
/// message itself, is animated. A walk that finds nothing puts the list back
/// where it started, so a tap can never cost somebody their place.
class TimelineJumpController {
  TimelineJumpController({required this.scroll, required this.loadOlder});

  final ScrollController scroll;

  /// Asks the feed for the page before the oldest message loaded, completing
  /// when it has landed (or immediately, when there is nothing more to fetch).
  final Future<void> Function() loadOlder;

  final _rows = <String, GlobalKey>{};

  /// The message drawn with a wash over it, just after a jump lands on it.
  final highlighted = ValueNotifier<String?>(null);

  bool _running = false;
  bool _disposed = false;

  /// How many screens of history one tap may walk back through.
  static const _maxSteps = 40;
  static const _flashFor = Duration(milliseconds: 1500);

  void bind(String messageId, GlobalKey key) => _rows[messageId] = key;

  void unbind(String messageId, GlobalKey key) {
    if (identical(_rows[messageId], key)) _rows.remove(messageId);
  }

  void dispose() {
    _disposed = true;
    highlighted.dispose();
  }

  /// Scrolls to [messageId] and flashes it. False when it could not be reached
  /// — it fell outside this feed, or off the end of the history the server
  /// still keeps.
  Future<bool> jumpTo(String messageId) async {
    if (messageId.isEmpty || _running || !scroll.hasClients) return false;
    _running = true;
    final startedAt = scroll.position.pixels;
    try {
      for (var step = 0; step <= _maxSteps; step++) {
        if (await _revealIfBuilt(messageId)) return true;
        if (!await _stepBack()) break;
      }
      if (await _revealIfBuilt(messageId)) return true;
      if (!_disposed && scroll.hasClients) {
        scroll.jumpTo(math.min(startedAt, scroll.position.maxScrollExtent));
      }
      return false;
    } finally {
      _running = false;
    }
  }

  Future<bool> _revealIfBuilt(String messageId) async {
    final target = _rows[messageId]?.currentContext;
    if (target == null || !target.mounted) return false;
    await Scrollable.ensureVisible(
      target,
      // A little above centre: the reply that was tapped stays in sight under
      // it, which is what makes the jump readable as an answer.
      alignment: 0.35,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _flash(messageId);
    return true;
  }

  /// One screen further into the history. False when there is no more of it.
  Future<bool> _stepBack() async {
    if (_disposed || !scroll.hasClients) return false;
    final position = scroll.position;
    final next = math.min(
      position.pixels + position.viewportDimension * 0.8,
      position.maxScrollExtent,
    );
    if (next > position.pixels + 1) {
      scroll.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
      return !_disposed;
    }
    final before = position.maxScrollExtent;
    await loadOlder();
    await WidgetsBinding.instance.endOfFrame;
    if (_disposed || !scroll.hasClients) return false;
    return scroll.position.maxScrollExtent > before + 1;
  }

  void _flash(String messageId) {
    if (_disposed) return;
    highlighted.value = messageId;
    Timer(_flashFor, () {
      if (_disposed) return;
      if (highlighted.value == messageId) highlighted.value = null;
    });
  }
}

/// Hands the controller to the rows and to every quote block under it. Absent
/// (and every jump a no-op) wherever a message is drawn outside a timeline —
/// the long-press overlay's floating copy, for one.
class TimelineJumpScope extends InheritedWidget {
  const TimelineJumpScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final TimelineJumpController controller;

  static TimelineJumpController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TimelineJumpScope>()
      ?.controller;

  @override
  bool updateShouldNotify(TimelineJumpScope oldWidget) =>
      !identical(oldWidget.controller, controller);
}
