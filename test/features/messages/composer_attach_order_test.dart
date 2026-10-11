import 'package:ababilx/features/messages/chat-timeline/composer_attach_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const d = AttachDestination.values;

  test('no saved order keeps the default order', () {
    expect(applyAttachOrder(d, const []), d);
  });

  test('a saved order is followed', () {
    expect(
      applyAttachOrder(
        const [
          AttachDestination.gallery,
          AttachDestination.camera,
          AttachDestination.task,
        ],
        const ['task', 'gallery', 'camera'],
      ),
      const [
        AttachDestination.task,
        AttachDestination.gallery,
        AttachDestination.camera,
      ],
    );
  });

  test('a chip the saved order never saw goes last, in default order', () {
    expect(
      applyAttachOrder(
        const [
          AttachDestination.gallery,
          AttachDestination.file,
          AttachDestination.snippet,
          AttachDestination.camera,
        ],
        const ['camera', 'gallery'],
      ),
      const [
        AttachDestination.camera,
        AttachDestination.gallery,
        AttachDestination.file,
        AttachDestination.snippet,
      ],
    );
  });

  test('a saved chip this chat does not offer is skipped', () {
    expect(
      applyAttachOrder(
        const [AttachDestination.gallery, AttachDestination.file],
        const ['ghost', 'file', 'gallery'],
      ),
      const [AttachDestination.file, AttachDestination.gallery],
    );
  });
}
