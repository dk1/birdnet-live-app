// =============================================================================
// Foreground Service Guard - mutual exclusion for the shared Android service
// =============================================================================
//
// ARU (serviceId 512) and Survey (serviceId 256) are both backed by the single
// `ForegroundService` declaration in AndroidManifest.xml. Only one mode may own
// that service at a time; starting a second mode while the first is still
// running would contend over the same foreground service.
//
// Each notification controller must [tryClaim] before `startService` and
// [release] after `stopService` (or when a start attempt fails).

/// The mode currently holding the shared Android foreground service.
enum ForegroundServiceOwner { survey, aru }

/// Process-wide tracker that enforces single ownership of the shared Android
/// foreground service across ARU and Survey.
class ForegroundServiceGuard {
  ForegroundServiceGuard._();

  static ForegroundServiceOwner? _owner;

  /// The current owner, or `null` when the foreground service is free.
  static ForegroundServiceOwner? get owner => _owner;

  /// Attempts to claim the foreground service for [owner].
  ///
  /// Returns `true` if [owner] already holds it or the service is free;
  /// returns `false` (without changing ownership) when a different mode owns it.
  static bool tryClaim(ForegroundServiceOwner owner) {
    if (_owner != null && _owner != owner) return false;
    _owner = owner;
    return true;
  }

  /// Releases the claim if [owner] currently holds it.
  static void release(ForegroundServiceOwner owner) {
    if (_owner == owner) _owner = null;
  }
}
