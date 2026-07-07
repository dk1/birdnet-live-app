// =============================================================================
// Relaunch Signal — distinguishes a same-app relaunch from real backgrounding
// =============================================================================
//
// Both the ARU notification's PendingIntent and the Quick Listen widget's
// PendingIntent use FLAG_ACTIVITY_NEW_TASK/CLEAR_TOP/SINGLE_TOP to bring the
// app back to a known route. When the app is already in the foreground,
// Android still briefly cycles the activity through AppLifecycleState
// .inactive during that relaunch even though it never really leaves the
// foreground. Screens that pause work on backgrounding (e.g. LiveScreen)
// need to tell that blip apart from a real backgrounding event.
//
// Usage: call [markExpected] immediately before navigating via one of these
// relaunch-style PendingIntents. The lifecycle handler then calls
// [consumeExpected] on the next inactive/paused transition — `true` means
// "skip pausing, this is that expected blip" — and the flag is cleared
// immediately, so it only ever suppresses the one transition it was set
// for, never a later, genuine backgrounding.
// =============================================================================

abstract final class RelaunchSignal {
  static bool _expected = false;

  static void markExpected() {
    _expected = true;
  }

  static bool consumeExpected() {
    final wasExpected = _expected;
    _expected = false;
    return wasExpected;
  }
}
