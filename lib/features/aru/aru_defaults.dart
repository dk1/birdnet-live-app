// =============================================================================
// ARU Defaults - Shared constants for autonomous recording deployments
// =============================================================================

/// Defaults and bounds for ARU setup.
///
/// These are feature-local constants, not persisted settings. Promote them to
/// `PrefKeys` and settings providers only when the app exposes user preferences
/// that should survive across setup flows.
abstract final class AruDefaults {
  static const Duration minCycleDuration = Duration(seconds: 30);
  static const Duration maxCycleDuration = Duration(minutes: 60);
  static const Duration defaultCycleDuration = Duration(minutes: 10);
  static const Duration defaultRepeatInterval = Duration(hours: 1);
  static const int defaultMaxCycles = 12;
  static const int defaultLowBatteryStopPercent = 15;
  static const int defaultStorageSafetyMarginBytes = 250 * 1024 * 1024;
  static const int defaultTestCycleSeconds = 60;

  /// Fixed length of the optional one-off test cycle (see [defaultTestCycleSeconds]).
  static const Duration testCycleDuration = Duration(
    seconds: defaultTestCycleSeconds,
  );

  static const List<Duration> cycleDurationOptions = <Duration>[
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 3),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 20),
    Duration(minutes: 30),
    Duration(minutes: 60),
  ];

  static const List<Duration> repeatIntervalOptions = <Duration>[
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 3),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 20),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 3),
    Duration(hours: 4),
    Duration(hours: 5),
  ];
}
