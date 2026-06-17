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

  /// Battery percentage at or below which ARU pauses recording cycles (the
  /// deployment keeps running and resumes once the battery recovers to
  /// [defaultLowBatteryResumePercent]). 0 disables battery management.
  static const int defaultLowBatteryStopPercent = 10;

  /// Battery percentage at or above which ARU resumes recording cycles after a
  /// low-battery pause. Should be greater than [defaultLowBatteryStopPercent] to
  /// avoid flapping (hysteresis), e.g. for occasional solar charging.
  static const int defaultLowBatteryResumePercent = 20;
  static const int minLowBatteryResumePercent = 5;
  static const int maxLowBatteryResumePercent = 55;
  static const int lowBatteryResumeStepPercent = 5;
  static const int lowBatteryResumeGapPercent = 5;
  static const int lowBatteryResumeDivisions =
      (maxLowBatteryResumePercent - minLowBatteryResumePercent) ~/
      lowBatteryResumeStepPercent;
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
