import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Whether a linked computer is reading this phone's chats right now.
class HistoryLiveState {
  const HistoryLiveState({this.open = false, this.device = ''});

  final bool open;
  final String device;
}

const _sync = MethodChannel('com.ababilx.app/history_sync');

/// Android keeps a dataSync foreground service up while the channel is open
/// (`historysync/HistorySyncService.kt`), so a backgrounded phone keeps
/// answering.
void historySyncService({required bool started, String device = ''}) {
  if (!Platform.isAndroid) return;
  final call = started
      ? _sync.invokeMethod('started', {'device': device})
      : _sync.invokeMethod('ended');
  unawaited(call.catchError((_) => null));
}
