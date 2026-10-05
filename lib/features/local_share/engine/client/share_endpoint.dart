import 'dart:io';

import '../protocol/share_routes.dart';

/// Where a paired device is right now, and the secret that opens it.
class ShareEndpoint {
  const ShareEndpoint({
    required this.ip,
    required this.port,
    required this.token,
    required this.selfDeviceId,
  });

  final String ip;
  final int port;
  final String token;

  /// OUR device id — the receiver looks the token up by it.
  final String selfDeviceId;

  Uri uri(String pathAndQuery) => Uri.parse('http://$ip:$port$pathAndQuery');

  void sign(HttpClientRequest request) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(ShareRoutes.deviceHeader, selfDeviceId);
  }
}

enum ShareSendOutcome {
  done,

  /// Some files did not make it; what did arrive is kept by the receiver.
  incomplete,

  /// Could not reach the device at all.
  unreachable,

  /// The receiver no longer knows our token: pair again.
  unpaired,
  canceled,
}

class ShareSendResult {
  const ShareSendResult(this.outcome, {this.doneFileIds = const {}});

  final ShareSendOutcome outcome;
  final Set<String> doneFileIds;
}

/// Stops a send from outside. Aborting the open requests is what makes it
/// immediate — a flag alone is only read between chunks.
class ShareCancel {
  bool _canceled = false;
  final _aborts = <void Function()>{};

  bool get canceled => _canceled;

  void cancel() {
    _canceled = true;
    for (final abort in _aborts.toList()) {
      abort();
    }
    _aborts.clear();
  }

  void attach(void Function() abort) =>
      _canceled ? abort() : _aborts.add(abort);
  void detach(void Function() abort) => _aborts.remove(abort);
}
