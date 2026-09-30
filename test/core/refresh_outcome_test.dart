import 'package:ababilx/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only 401/403 on refresh end the session', () {
    expect(refreshOutcomeForStatus(401), RefreshOutcome.rejected);
    expect(refreshOutcomeForStatus(403), RefreshOutcome.rejected);
  });

  test('no answer or a server fault keeps the session', () {
    // null = no response at all: offline, DNS, timeout — a phone just out of
    // Doze. It must never sign the user out.
    expect(refreshOutcomeForStatus(null), RefreshOutcome.unavailable);
    expect(refreshOutcomeForStatus(500), RefreshOutcome.unavailable);
    expect(refreshOutcomeForStatus(502), RefreshOutcome.unavailable);
    expect(refreshOutcomeForStatus(429), RefreshOutcome.unavailable);
  });
}
