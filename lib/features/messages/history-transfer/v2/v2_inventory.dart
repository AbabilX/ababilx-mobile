import 'v2_api.dart';
import 'v2_batch_uploader.dart';
import 'v2_crypto.dart';
import 'v2_media_plan.dart';
import 'v2_plan.dart';

/// The phone's sealed count of what it is about to send (protocol 4.4), so the
/// browser can size storage before the first batch lands.
Future<String> sealInventory(V2Plan plan, List<int> key) {
  final available = plan.files.where((f) => f.status == 'available');
  return HistoryTransferV2Crypto.sealJson(key, HistoryTransferV2Crypto.inventoryAad(plan.transferId), {
    'v': HistoryTransferV2Crypto.version,
    'transfer_id': plan.transferId,
    'created_at_ms': plan.createdAtMs,
    'conversations': plan.conversationCount,
    'messages': plan.messageCount,
    'message_bytes_estimate': plan.batches
        .where((b) => b.kind == 'messages')
        .fold<int>(0, (sum, b) => sum + b.streamBytes),
    'files': available.length,
    'file_bytes': available.fold<int>(0, (sum, f) => sum + f.size),
    'missing_files': plan.files.where((f) => f.status == 'missing').length,
    'batches': plan.batches.length,
  });
}

/// The job seal (protocol 4.5): names the last batch, so the browser can never
/// be told a truncated sequence is finished, and carries the final deletions.
Future<String> sealJobSeal(V2Plan plan, List<int> key, List<Map<String, dynamic>> deletions) =>
    HistoryTransferV2Crypto.sealJson(key, HistoryTransferV2Crypto.sealAad(plan.transferId), {
      'v': HistoryTransferV2Crypto.version,
      'transfer_id': plan.transferId,
      'last_batch': plan.lastBatch,
      'batch_count': plan.batches.length,
      'messages': plan.messageCount,
      'conversations': plan.conversationCount,
      'files_sent': plan.files.where((f) => f.status == 'available').length,
      'files_missing': plan.files.where((f) => f.status == 'missing').length,
      'files_omitted': plan.files.where((f) => f.status == 'omitted').length,
      'deletions': deletions,
    });

/// Files the browser already holds, from its sealed inventory. Waited for at
/// most [wait] — a browser that never sends one just gets everything.
Future<List<V2HeldFile>> waitForDestinationInventory(
  HistoryTransferV2Api api,
  String transferId,
  List<int> key, {
  Duration wait = const Duration(seconds: 60),
  Duration pollEvery = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(wait);
  while (DateTime.now().isBefore(deadline)) {
    try {
      final job = await retrying(() => api.job(transferId));
      final transfer = job['transfer'];
      final sealed = transfer is Map ? transfer['dest_inventory_ciphertext'] as String? ?? '' : '';
      if (sealed.isNotEmpty) {
        final opened = await HistoryTransferV2Crypto.openJson(
          key,
          HistoryTransferV2Crypto.destInventoryAad(transferId),
          sealed,
        );
        final files = opened is Map ? (opened['complete_files'] as List? ?? []) : const [];
        return [
          for (final f in files.whereType<Map>())
            (
              urlKey: f['url_key'] as String? ?? '',
              sha256: f['sha256'] as String? ?? '',
              size: (f['size'] as num?)?.toInt() ?? -1,
            ),
        ];
      }
    } catch (_) {
      // An inventory that will not open is treated as none: the phone sends
      // everything, which costs bandwidth and nothing else.
      return const [];
    }
    await Future<void>.delayed(pollEvery);
  }
  return const [];
}
