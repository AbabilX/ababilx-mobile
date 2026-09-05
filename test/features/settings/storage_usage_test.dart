import 'package:ababilx/features/attachments/storage/storage_usage.dart';
import 'package:ababilx/shared/text/byte_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('storage buckets', () {
    test('a blob is bucketed by the same rules the renderer uses', () {
      expect(
        storageBucketOf(fileName: 'a.jpg', contentType: 'image/jpeg'),
        StorageBucket.photos,
      );
      expect(
        storageBucketOf(fileName: 'a.mp4', contentType: 'video/mp4'),
        StorageBucket.videos,
      );
      expect(
        storageBucketOf(fileName: 'note.m4a', contentType: 'audio/mp4'),
        StorageBucket.audio,
      );
      expect(
        storageBucketOf(fileName: 'deal.pdf', contentType: 'application/pdf'),
        StorageBucket.documents,
      );
    });

    test('a row with no content type still lands somewhere', () {
      expect(
        storageBucketOf(fileName: 'photo.HEIC', contentType: ''),
        StorageBucket.photos,
      );
      expect(
        storageBucketOf(fileName: '', contentType: ''),
        StorageBucket.documents,
      );
    });

    test('.webm is video before it is audio, as it is in the timeline', () {
      expect(
        storageBucketOf(fileName: 'clip.webm', contentType: ''),
        StorageBucket.videos,
      );
    });
  });

  group('storage usage', () {
    const usage = StorageUsage(
      bytes: {
        StorageBucket.photos: 100,
        StorageBucket.videos: 900,
        StorageBucket.audio: 0,
      },
      counts: {StorageBucket.photos: 2, StorageBucket.videos: 1},
    );

    test('totals and the legend order', () {
      expect(usage.total, 1000);
      expect(usage.count, 3);
      // Biggest first, and an empty bucket never reaches the legend.
      expect(usage.occupied, [StorageBucket.videos, StorageBucket.photos]);
    });

    test('an empty store is empty rather than zero-length', () {
      expect(StorageUsage.empty.isEmpty, isTrue);
      expect(StorageUsage.empty.occupied, isEmpty);
      expect(StorageUsage.empty.bytesFor(StorageBucket.photos), 0);
    });
  });

  group('byte labels', () {
    test('scales through the units', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(-5), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
    });

    test('drops the decimal once it stops meaning anything', () {
      expect(formatBytes(700 * 1024 * 1024), '700 MB');
    });
  });
}
