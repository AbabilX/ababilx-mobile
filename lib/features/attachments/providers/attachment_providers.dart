import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/data/local/chat_sidebar_cache.dart'
    show chatLocalDbProvider;
import '../../messages/data/models/chat_attachment.dart';
import '../data/local/attachment_blob_store.dart';
import '../data/local/attachment_dedupe_store.dart';
import '../data/local/attachment_ref_store.dart';
import '../data/models/attachment_handle.dart';
import '../services/attachment_adopter.dart';
import '../services/attachment_authority.dart';
import '../services/attachment_cipher.dart';
import '../services/attachment_downloader.dart';
import '../services/attachment_exporter.dart';
import '../services/attachment_intake.dart';
import '../services/attachment_paths.dart';
import '../services/attachment_queue.dart';
import '../services/attachment_sweeper.dart';

final attachmentBlobStoreProvider = Provider<AttachmentBlobStore>(
  (ref) => AttachmentBlobStore(ref.watch(chatLocalDbProvider)),
);

final attachmentRefStoreProvider = Provider<AttachmentRefStore>(
  (ref) => AttachmentRefStore(ref.watch(chatLocalDbProvider)),
);

final attachmentDedupeStoreProvider = Provider<AttachmentDedupeStore>(
  (ref) => AttachmentDedupeStore(ref.watch(chatLocalDbProvider)),
);

final attachmentPathsProvider = Provider<AttachmentPaths>(
  (ref) => AttachmentPaths(),
);

/// Attachments are stored in the clear on R2 today. Binding a real cipher here
/// is the whole of "add encryption" as far as the download flow is concerned.
final attachmentCipherProvider = Provider<AttachmentCipher>(
  (ref) => const PassthroughAttachmentCipher(),
);

/// A bare Dio with **no interceptors**.
///
/// Attachment URLs are public and unsigned on the R2 custom domain, so
/// [ApiClient]'s auth interceptor must never touch them — sending a bearer
/// token to a third-party asset host leaks it, and its 401-refresh path would
/// fire on an asset 401 that has nothing to do with the session.
final attachmentDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      // No receiveTimeout: it applies to the whole streamed body, so a large
      // file on a slow connection would be killed mid-transfer.
      receiveTimeout: null,
    ),
  );
});

final attachmentDownloaderProvider = Provider<AttachmentDownloader>(
  (ref) => AttachmentDownloader(
    ref.watch(attachmentDioProvider),
    ref.watch(attachmentCipherProvider),
  ),
);

final attachmentExporterProvider = Provider<AttachmentExporter>(
  (ref) => AttachmentExporter(ref.watch(attachmentBlobStoreProvider)),
);

/// Owns every in-flight transfer for the life of the app — never autoDispose,
/// so scrolling away from a bubble does not cancel its download.
final attachmentQueueProvider = Provider<AttachmentQueue>((ref) {
  final exporter = ref.watch(attachmentExporterProvider);
  final queue = AttachmentQueue(
    ref.watch(attachmentBlobStoreProvider),
    ref.watch(attachmentDedupeStoreProvider),
    ref.watch(attachmentPathsProvider),
    ref.watch(attachmentDownloaderProvider),
    onReady: exporter.export,
  );
  ref.onDispose(queue.dispose);
  return queue;
});

/// Files the sender already holds go straight into the store — see
/// [AttachmentAdopter]. Not autoDispose: an adoption outlives the composer.
final attachmentAdopterProvider = Provider<AttachmentAdopter>(
  (ref) => AttachmentAdopter(
    ref.watch(attachmentBlobStoreProvider),
    ref.watch(attachmentDedupeStoreProvider),
    ref.watch(attachmentPathsProvider),
    ref.watch(attachmentQueueProvider),
  ),
);

final attachmentAuthorityProvider = Provider<AttachmentAuthority>((ref) {
  final authority = AttachmentAuthority(
    ref.watch(attachmentBlobStoreProvider),
    ref.watch(attachmentQueueProvider),
  );
  ref.onDispose(authority.dispose);
  return authority;
});

final attachmentIntakeProvider = Provider<AttachmentIntake>(
  (ref) => AttachmentIntake(
    ref.watch(attachmentBlobStoreProvider),
    ref.watch(attachmentRefStoreProvider),
    ref.watch(attachmentQueueProvider),
  ),
);

final attachmentSweeperProvider = Provider<AttachmentSweeper>(
  (ref) => AttachmentSweeper(
    ref.watch(attachmentBlobStoreProvider),
    ref.watch(attachmentDedupeStoreProvider),
    ref.watch(attachmentRefStoreProvider),
    ref.watch(attachmentPathsProvider),
  ),
);

/// One attachment's live state.
///
/// autoDispose is safe precisely because the transfer is owned by
/// [AttachmentQueue]: dropping the listener stops the rebuilds, not the
/// download. Only leaf tiles watch this, so a progress tick repaints one
/// thumbnail rather than the timeline.
final attachmentHandleProvider = StreamProvider.autoDispose
    .family<AttachmentHandle, ChatMessageAttachment>(
      (ref, attachment) =>
          ref.watch(attachmentAuthorityProvider).watch(attachment),
    );
