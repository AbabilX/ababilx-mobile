/// Every tuning knob for the local attachment store, in one place so the
/// service files stay short and a policy change is a one-line diff.
library;

/// Ceiling for an automatic (un-tapped) download. Anything larger waits for
/// the user, exactly like WhatsApp's media auto-download cap.
const int autoDownloadMaxBytes = 5 * 1024 * 1024;

/// Transfers running at once, across every conversation. Three keeps a slow
/// connection responsive without starving a tapped download behind a queue of
/// automatic ones.
const int maxConcurrentDownloads = 3;

/// Attempts before a transfer is parked as retryable-failed. A user-initiated
/// download tries harder than a background one.
const int maxUserAttempts = 3;
const int maxAutoAttempts = 2;

/// Sleep before each retry. The sticky `.part` file means attempt N+1 resumes
/// rather than restarting, so waiting costs nothing already transferred.
const List<Duration> retryBackoff = [
  Duration(seconds: 1),
  Duration(seconds: 4),
  Duration(seconds: 15),
];

/// Random extra delay added to a retry so a reconnect does not fire every
/// parked transfer in the same millisecond.
const int retryJitterMs = 400;

/// Progress is only emitted this often, or on this much movement — a 40 MB
/// video would otherwise push thousands of rebuilds through the UI.
const Duration progressEmitInterval = Duration(milliseconds: 120);
const double progressEmitDelta = 0.01;

/// How often in-flight progress is written to the database. Between writes the
/// `.part` file's own length is the source of truth, so a crash loses at most
/// a row update, never bytes.
const Duration progressPersistInterval = Duration(seconds: 2);

/// Total bytes of downloaded attachments to keep. Past this the least recently
/// used files are evicted back to "not downloaded".
const int diskBudgetBytes = 512 * 1024 * 1024;

/// Never evict something touched more recently than this, or smaller than
/// this — voice notes are cheap and re-read often.
const Duration evictionMinIdle = Duration(days: 7);
const int evictionMinBytes = 1024 * 1024;

/// A `.part` with no matching row is swept once it is this old.
const Duration stalePartMaxAge = Duration(days: 7);

/// The orphan sweep is expensive enough to be worth running rarely.
const Duration sweepInterval = Duration(hours: 24);

/// `lastAccessMs` is only rewritten this often per blob — a scrolling timeline
/// resolves the same attachment many times a second.
const Duration touchInterval = Duration(hours: 1);
