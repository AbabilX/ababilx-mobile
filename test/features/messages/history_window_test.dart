import 'package:ababilx/features/messages/history-transfer/history_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the server figure wins; missing or nonsense means 90 days', () {
    expect(historyWindowDays(null), 90);
    expect(historyWindowDays(0), 90);
    expect(historyWindowDays(-5), 90);
    expect(historyWindowDays('90'), 90);
    expect(historyWindowDays(30), 30);
    expect(historyWindowDays(120.0), 120);
  });

  test('the cursor lets a message sent exactly at the cutoff through', () {
    final now = DateTime.utc(2026, 10, 18);
    final cutoff = DateTime.utc(2026, 7, 20).millisecondsSinceEpoch;
    expect(historyWindowAfterMs(90, now), cutoff - 1);
  });

  test('labels read as months when they are whole months', () {
    expect(historyWindowLabel(90), '3 months');
    expect(historyWindowLabel(30), '1 month');
    expect(historyWindowLabel(45), '45 days');
    expect(historyWindowLabel(1), '1 day');
  });
}
