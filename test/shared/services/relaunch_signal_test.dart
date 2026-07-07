// =============================================================================
// Relaunch Signal Tests
// =============================================================================
//
// Verifies the one-shot mark/consume behavior that lets a same-app relaunch
// (Quick Listen widget, ARU notification action) tell LiveScreen's lifecycle
// handler to skip pausing for exactly one inactive/paused transition.
// =============================================================================

import 'package:birdnet_live/shared/services/relaunch_signal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RelaunchSignal', () {
    test('consumeExpected is false when nothing was marked', () {
      expect(RelaunchSignal.consumeExpected(), isFalse);
    });

    test('consumeExpected is true exactly once after markExpected', () {
      RelaunchSignal.markExpected();

      expect(RelaunchSignal.consumeExpected(), isTrue);
      expect(RelaunchSignal.consumeExpected(), isFalse);
    });

    test('a second markExpected re-arms it after being consumed', () {
      RelaunchSignal.markExpected();
      expect(RelaunchSignal.consumeExpected(), isTrue);

      RelaunchSignal.markExpected();
      expect(RelaunchSignal.consumeExpected(), isTrue);
      expect(RelaunchSignal.consumeExpected(), isFalse);
    });

    test('marking twice before consuming still only suppresses one transition', () {
      RelaunchSignal.markExpected();
      RelaunchSignal.markExpected();

      expect(RelaunchSignal.consumeExpected(), isTrue);
      expect(RelaunchSignal.consumeExpected(), isFalse);
    });
  });
}
