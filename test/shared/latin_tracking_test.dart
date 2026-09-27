import 'package:ababilx/shared/text/latin_tracking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Latin keeps its tracking, any Bengali drops it', () {
    expect(latinTracking('TODAY', 0.4), 0.4);
    expect(latinTracking('আজ', 0.4), 0);
    expect(latinTracking('Admin · গুপ্ত আওয়ামী', 0.5), 0);
    expect(latinTracking('', 0.4), 0.4);
  });
}
