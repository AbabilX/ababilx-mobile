import 'package:ababilx/shared/media/picked_media_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps common attachment file types', () {
    expect(contentTypeForFileName('receipt.pdf'), 'application/pdf');
    expect(contentTypeForFileName('voice-message-8s.m4a'), 'audio/mp4');
    expect(
      contentTypeForFileName('proposal.docx'),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(contentTypeForFileName('clip.mp4'), 'video/mp4');
    expect(contentTypeForFileName('clip.mov'), 'video/quicktime');
  });
}
