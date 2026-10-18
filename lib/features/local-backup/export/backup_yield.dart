/// Gives the event loop a turn every few milliseconds of backup work.
///
/// The backup runs on the UI isolate (the vault's keys live there), and the
/// scan handles a whole page of rows without awaiting anything real: 500
/// rows were one block of 60–80 ms on a phone, several dropped frames in the
/// chat list the scheduled run sits behind. A zero timer lets a frame in.
class BackupYield {
  BackupYield({this.budget = const Duration(milliseconds: 6)});

  final Duration budget;
  final _watch = Stopwatch()..start();

  Future<void> maybe() async {
    if (_watch.elapsed < budget) return;
    await Future<void>.delayed(Duration.zero);
    _watch.reset();
  }
}
