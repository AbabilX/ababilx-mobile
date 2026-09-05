import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/data/local/chat_sidebar_cache.dart'
    show chatLocalDbProvider;
import '../providers/attachment_providers.dart';
import 'storage_manager.dart';
import 'storage_usage.dart';
import 'storage_usage_query.dart';

final storageUsageQueryProvider = Provider<StorageUsageQuery>(
  (ref) => StorageUsageQuery(ref.watch(chatLocalDbProvider)),
);

final storageManagerProvider = Provider<StorageManager>(
  (ref) => StorageManager(
    ref.watch(attachmentBlobStoreProvider),
    ref.watch(attachmentDedupeStoreProvider),
    ref.watch(storageUsageQueryProvider),
  ),
);

/// Recomputed on demand: `ref.invalidate` after a delete is what refreshes
/// every screen showing a number, rather than each of them tracking its own.
final storageUsageProvider = FutureProvider<StorageUsage>(
  (ref) => ref.watch(storageUsageQueryProvider).total(),
);

final storageByConversationProvider = FutureProvider<List<ConversationStorage>>(
  (ref) => ref.watch(storageUsageQueryProvider).byConversation(),
);

/// Review storage's list, optionally narrowed to one bucket.
final storageItemsProvider =
    FutureProvider.family<List<StorageItem>, StorageBucket?>(
      (ref, bucket) =>
          ref.watch(storageUsageQueryProvider).items(bucket: bucket),
    );
