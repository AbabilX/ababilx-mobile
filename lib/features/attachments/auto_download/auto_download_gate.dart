import '../../../core/network/network_class.dart';
import '../../../core/network/network_probe.dart';
import '../../messages/data/models/chat_attachment.dart';
import '../services/attachment_policy.dart';
import 'auto_download_settings.dart';
import 'auto_download_store.dart';

/// Binds the user's auto-download choice to what this connection costs.
///
/// Resolved once per batch of arriving messages rather than per attachment:
/// [resolve] does the two awaits, and the returned [AutoDownloadDecision]
/// answers the rest of the loop synchronously.
///
/// Both dependencies arrive as functions so a test can pin them without a
/// SharedPreferences mock and a live connectivity plugin — see [AutoDownloadGate.fixed].
class AutoDownloadGate {
  const AutoDownloadGate({
    required this.readSettings,
    required this.readNetwork,
  });

  AutoDownloadGate.of(AutoDownloadStore store, NetworkProbe probe)
    : readSettings = store.read,
      readNetwork = probe.current;

  /// A gate that always answers the same way.
  AutoDownloadGate.fixed({
    AutoDownloadSettings settings = AutoDownloadSettings.defaults,
    NetworkClass network = NetworkClass.wifi,
  }) : readSettings = (() async => settings),
       readNetwork = (() async => network);

  final Future<AutoDownloadSettings> Function() readSettings;
  final Future<NetworkClass> Function() readNetwork;

  Future<AutoDownloadDecision> resolve() async => AutoDownloadDecision(
    settings: await readSettings(),
    network: await readNetwork(),
  );
}

/// One batch's answer. Immutable, so a connection changing mid-loop cannot
/// make two attachments of the same message disagree.
class AutoDownloadDecision {
  const AutoDownloadDecision({required this.settings, required this.network});

  final AutoDownloadSettings settings;
  final NetworkClass network;

  bool allows(ChatMessageAttachment attachment) =>
      shouldAutoDownload(attachment, settings: settings, network: network);
}
