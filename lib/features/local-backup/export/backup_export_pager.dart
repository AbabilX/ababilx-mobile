import '../../messages/data/local/chat_message_row.dart';
import '../../messages/data/models/chat_message.dart';

/// The store's export pages as one stream of rows, with a seek.
///
/// The write pass of the automatic backup reads a week again from the cursor
/// the scan noted. Weeks that need writing are usually next to each other
/// (this week, last week), and reading each from its own cursor fetched the
/// page that ends one week twice, once per side. A seek that lands inside
/// the page already held keeps it.
class BackupExportPager {
  BackupExportPager(this._read);

  final Future<List<ChatMessage>> Function(int? afterMs, String? afterId) _read;

  List<ChatMessage> _page = const [];
  int _next = 0;
  bool _end = false;

  /// Where the next read starts: the last row of [_page], or a seek point.
  int? _afterMs;
  String? _afterId;

  /// The last row handed out (or the seek point).
  int? _takenMs;
  String? _takenId;

  /// Time spent in the store, and pages read, for the run's log line.
  final watch = Stopwatch();
  int pages = 0;

  /// Moves to just after the row (afterMs, afterId), the store's own cursor.
  void seek(int? afterMs, String? afterId) {
    if (_next < _page.length && _holds(afterMs, afterId)) {
      // Everything between here and the target is skipped by the caller,
      // which stops at the week it wants — no read needed.
      return;
    }
    _page = const [];
    _next = 0;
    _end = false;
    _afterMs = _takenMs = afterMs;
    _afterId = _takenId = afterId;
  }

  /// True when the target lies in the rows still buffered: at or after what
  /// was handed out, before the buffered page's last row.
  bool _holds(int? ms, String? id) {
    final last = _page.last;
    return _compare(ms, id, _takenMs, _takenId) >= 0 &&
        _compare(ms, id, messageTimeMs(last), localMessageRowId(last)) < 0;
  }

  /// The next row without taking it, or null at the end of the store.
  Future<ChatMessage?> peek() async {
    if (_next < _page.length) return _page[_next];
    if (_end) return null;
    watch.start();
    final page = await _read(_afterMs, _afterId);
    watch.stop();
    pages++;
    if (page.isEmpty) {
      _end = true;
      _page = const [];
      _next = 0;
      return null;
    }
    _page = page;
    _next = 0;
    _afterMs = messageTimeMs(page.last);
    _afterId = localMessageRowId(page.last);
    return page.first;
  }

  /// Takes the row [peek] returned.
  void take() {
    final message = _page[_next++];
    _takenMs = messageTimeMs(message);
    _takenId = localMessageRowId(message);
  }

  /// Store order: time, then row id. No cursor sorts before every row.
  static int _compare(int? aMs, String? aId, int? bMs, String? bId) {
    if (aMs == null || bMs == null) {
      return aMs == null ? (bMs == null ? 0 : -1) : 1;
    }
    final byTime = aMs.compareTo(bMs);
    return byTime != 0 ? byTime : (aId ?? '').compareTo(bId ?? '');
  }
}
