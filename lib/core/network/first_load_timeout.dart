/// Bound on a *first-ever-load* network call (no local cache to fall back
/// to yet — profile, team gate, chat sidebar). Shorter than Dio's own
/// connect+receive timeouts so a weak or dead connection fails into the
/// app's offline UI quickly instead of leaving a bare spinner on screen for
/// up to 45s. Background refreshes behind an already-cached value are not
/// bound by this — they can take their time since cached content is already
/// on screen.
const firstLoadNetworkTimeout = Duration(seconds: 8);
