import 'package:ababilx/features/messages/chat-timeline/composer_recent_selection_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recentSelectionBadgeLabel', () {
    test('singular and plural photos in English', () {
      expect(
        recentSelectionBadgeLabel(photoCount: 1, videoCount: 0, bengali: false),
        '1 image added',
      );
      expect(
        recentSelectionBadgeLabel(photoCount: 3, videoCount: 0, bengali: false),
        '3 images added',
      );
    });

    test('videos and mixed items', () {
      expect(
        recentSelectionBadgeLabel(photoCount: 0, videoCount: 2, bengali: false),
        '2 videos added',
      );
      expect(
        recentSelectionBadgeLabel(photoCount: 1, videoCount: 2, bengali: false),
        '3 items added',
      );
    });

    test('Bengali photo copy', () {
      expect(
        recentSelectionBadgeLabel(photoCount: 1, videoCount: 0, bengali: true),
        '১টি ছবি যোগ হয়েছে',
      );
      expect(
        recentSelectionBadgeLabel(photoCount: 3, videoCount: 0, bengali: true),
        '3টি ছবি যোগ হয়েছে',
      );
    });
  });
}
