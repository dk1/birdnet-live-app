// =============================================================================
// ARU Schedule - Pure scheduling domain for autonomous recording deployments
// =============================================================================

import 'dart:math' as math;

import 'aru_defaults.dart';

/// High-level schedule status at a point in time.
enum AruScheduleStatus {
  /// The deployment has not reached its first possible recording window.
  notStarted,

  /// The deployment is between recording windows.
  waiting,

  /// The deployment is inside an active recording window.
  recording,

  /// No more windows are allowed by the configured end condition.
  completed,
}

/// Optional day/night restriction for ARU recording windows.
enum AruDielPattern {
  /// No diel restriction; repeat windows run around the clock.
  anyTime,

  /// Daylight-only windows.
  dayOnly,

  /// Night-only windows.
  nightOnly,

  /// Windows around local sunrise.
  aroundSunrise,

  /// Windows around local sunset.
  aroundSunset,
}

/// User-configured repeating ARU schedule.
class AruScheduleConfig {
  const AruScheduleConfig({
    required this.startTime,
    required this.cycleDuration,
    required this.repeatInterval,
    this.endTime,
    this.maxCycles,
    this.lowBatteryStopPercent,
    this.dielPattern = AruDielPattern.anyTime,
    this.latitude,
    this.longitude,
  });

  /// First time at which a recording cycle may start.
  final DateTime startTime;

  /// Duration of every active recording cycle.
  final Duration cycleDuration;

  /// Time from one cycle start to the next cycle start.
  final Duration repeatInterval;

  /// Optional wall-clock deployment end. Cycles starting at or after this time
  /// are not scheduled; cycles already active at this time are clamped.
  final DateTime? endTime;

  /// Optional maximum number of cycles, counted from [startTime].
  final int? maxCycles;

  /// Optional graceful stop threshold. Battery measurement is outside this
  /// pure scheduler; this value is stored so controllers can enforce it.
  final int? lowBatteryStopPercent;

  /// Optional diel restriction.
  final AruDielPattern dielPattern;

  /// Optional deployment latitude for sunrise/sunset estimation.
  final double? latitude;

  /// Optional deployment longitude for sunrise/sunset estimation.
  final double? longitude;

  /// Returns validation errors. Empty means this config can be scheduled.
  List<String> validate() {
    final errors = <String>[];
    if (cycleDuration < AruDefaults.minCycleDuration) {
      errors.add('cycleDuration must be at least 1 minute');
    }
    if (cycleDuration > AruDefaults.maxCycleDuration) {
      errors.add('cycleDuration must be at most 60 minutes');
    }
    if (repeatInterval < cycleDuration) {
      errors.add(
        'repeatInterval must be greater than or equal to cycleDuration',
      );
    }
    if (endTime != null && !endTime!.isAfter(startTime)) {
      errors.add('endTime must be after startTime');
    }
    if (maxCycles != null && maxCycles! <= 0) {
      errors.add('maxCycles must be greater than zero');
    }
    if (lowBatteryStopPercent != null &&
        (lowBatteryStopPercent! < 0 || lowBatteryStopPercent! > 100)) {
      errors.add('lowBatteryStopPercent must be between 0 and 100');
    }
    return errors;
  }

  /// Throws [ArgumentError] when [validate] reports any errors.
  void validateOrThrow() {
    final errors = validate();
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.join('; '));
    }
  }
}

/// Estimated local sunrise and sunset for one date.
class AruSunTimes {
  const AruSunTimes({required this.sunrise, required this.sunset});

  final DateTime sunrise;
  final DateTime sunset;
}

/// Estimate local sunrise/sunset for ARU schedule previews.
///
/// Uses a compact NOAA-style approximation. If location is unavailable or the
/// solar calculation is undefined for the latitude/date, falls back to 06:00
/// and 18:00 local time as requested by the setup flow.
AruSunTimes estimateAruSunTimes({
  required DateTime date,
  double? latitude,
  double? longitude,
}) {
  final localMidnight =
      date.isUtc
          ? DateTime.utc(date.year, date.month, date.day)
          : DateTime(date.year, date.month, date.day);
  if (latitude == null || longitude == null) {
    return AruSunTimes(
      sunrise: localMidnight.add(const Duration(hours: 6)),
      sunset: localMidnight.add(const Duration(hours: 18)),
    );
  }

  final dayOfYear = _dayOfYear(date);
  final gamma = 2 * math.pi / 365 * (dayOfYear - 1);
  final equationOfTime =
      229.18 *
      (0.000075 +
          0.001868 * math.cos(gamma) -
          0.032077 * math.sin(gamma) -
          0.014615 * math.cos(2 * gamma) -
          0.040849 * math.sin(2 * gamma));
  final declination =
      0.006918 -
      0.399912 * math.cos(gamma) +
      0.070257 * math.sin(gamma) -
      0.006758 * math.cos(2 * gamma) +
      0.000907 * math.sin(2 * gamma) -
      0.002697 * math.cos(3 * gamma) +
      0.00148 * math.sin(3 * gamma);

  final latRad = latitude * math.pi / 180;
  final zenith = 90.833 * math.pi / 180;
  final hourAngleInput =
      (math.cos(zenith) / (math.cos(latRad) * math.cos(declination))) -
      (math.tan(latRad) * math.tan(declination));

  if (hourAngleInput < -1 || hourAngleInput > 1) {
    return AruSunTimes(
      sunrise: localMidnight.add(const Duration(hours: 6)),
      sunset: localMidnight.add(const Duration(hours: 18)),
    );
  }

  final hourAngleDegrees = math.acos(hourAngleInput) * 180 / math.pi;
  final timezoneOffsetMinutes = date.timeZoneOffset.inMinutes;
  final solarNoonMinutes =
      720 - 4 * longitude - equationOfTime + timezoneOffsetMinutes;
  final sunriseMinutes = (solarNoonMinutes - hourAngleDegrees * 4).round();
  final sunsetMinutes = (solarNoonMinutes + hourAngleDegrees * 4).round();

  return AruSunTimes(
    sunrise: localMidnight.add(Duration(minutes: sunriseMinutes)),
    sunset: localMidnight.add(Duration(minutes: sunsetMinutes)),
  );
}

int _dayOfYear(DateTime date) {
  final startOfYear = date.isUtc ? DateTime.utc(date.year) : DateTime(date.year);
  return date.difference(startOfYear).inDays + 1;
}

/// One scheduled ARU recording window.
class AruCycleWindow {
  const AruCycleWindow({
    required this.index,
    required this.start,
    required this.end,
    required this.plannedEnd,
  });

  /// Zero-based cycle index.
  final int index;

  /// Scheduled cycle start.
  final DateTime start;

  /// Effective cycle end, clamped by deployment end when configured.
  final DateTime end;

  /// Unclamped end derived from start + cycle duration.
  final DateTime plannedEnd;

  /// Whether [time] falls inside this active recording window.
  bool contains(DateTime time) => !time.isBefore(start) && time.isBefore(end);

  /// Whether this cycle was shortened by the deployment end time.
  bool get isClamped => end.isBefore(plannedEnd);
}

/// Schedule evaluation result for one point in time.
class AruScheduleSnapshot {
  const AruScheduleSnapshot({
    required this.status,
    required this.skippedCycles,
    this.currentWindow,
    this.nextWindow,
  });

  final AruScheduleStatus status;
  final AruCycleWindow? currentWindow;
  final AruCycleWindow? nextWindow;

  /// Number of windows whose end is before or equal to the evaluated time.
  final int skippedCycles;

  bool get isRecording => status == AruScheduleStatus.recording;
  bool get isWaiting => status == AruScheduleStatus.waiting;
  bool get isCompleted => status == AruScheduleStatus.completed;
}

/// Pure ARU schedule calculator.
class AruScheduleCalculator {
  AruScheduleCalculator(this.config) {
    config.validateOrThrow();
  }

  final AruScheduleConfig config;

  /// Evaluate the deployment state at [now].
  AruScheduleSnapshot snapshotAt(DateTime now) {
    if (now.isBefore(config.startTime)) {
      return AruScheduleSnapshot(
        status: AruScheduleStatus.notStarted,
        skippedCycles: 0,
        nextWindow: _windowAt(0),
      );
    }

    final candidateIndex = _cycleIndexAt(now);
    final current = _windowAt(candidateIndex);
    final skipped = _skippedCyclesAt(now);

    if (current == null) {
      return AruScheduleSnapshot(
        status: AruScheduleStatus.completed,
        skippedCycles: skipped,
      );
    }

    if (current.contains(now)) {
      return AruScheduleSnapshot(
        status: AruScheduleStatus.recording,
        skippedCycles: skipped,
        currentWindow: current,
        nextWindow: _windowAt(candidateIndex + 1),
      );
    }

    final next =
        now.isBefore(current.start) ? current : _windowAt(candidateIndex + 1);
    if (next == null) {
      return AruScheduleSnapshot(
        status: AruScheduleStatus.completed,
        skippedCycles: skipped,
      );
    }

    return AruScheduleSnapshot(
      status: AruScheduleStatus.waiting,
      skippedCycles: skipped,
      nextWindow: next,
    );
  }

  /// Returns up to [count] future windows starting at or after [from].
  List<AruCycleWindow> nextWindows(DateTime from, {int count = 3}) {
    if (count <= 0) return const [];
    final windows = <AruCycleWindow>[];
    var index = from.isBefore(config.startTime) ? 0 : _cycleIndexAt(from);

    while (windows.length < count) {
      final window = _windowAt(index);
      if (window == null) break;
      if (window.end.isAfter(from)) {
        windows.add(window);
      }
      index++;
    }

    return windows;
  }

  int _cycleIndexAt(DateTime time) {
    var index = 0;
    while (true) {
      final window = _windowAt(index);
      if (window == null || window.end.isAfter(time)) return index;
      index++;
    }
  }

  int _skippedCyclesAt(DateTime time) {
    var skipped = 0;
    while (true) {
      final window = _windowAt(skipped);
      if (window == null || window.end.isAfter(time)) return skipped;
      skipped++;
    }
  }

  AruCycleWindow? _windowAt(int index) {
    if (index < 0) return null;
    if (config.maxCycles != null && index >= config.maxCycles!) return null;

    if (config.dielPattern == AruDielPattern.anyTime) {
      return _candidateWindow(rawIndex: index, windowIndex: index);
    }

    var accepted = 0;
    var rawIndex = 0;
    while (rawIndex < 200000) {
      final candidate = _candidateWindow(
        rawIndex: rawIndex,
        windowIndex: accepted,
      );
      if (candidate == null) return null;
      if (_isAllowedStart(candidate.start)) {
        if (accepted == index) return candidate;
        accepted++;
      }
      rawIndex++;
    }
    return null;
  }

  AruCycleWindow? _candidateWindow({
    required int rawIndex,
    required int windowIndex,
  }) {
    final start = config.startTime.add(config.repeatInterval * rawIndex);
    final plannedEnd = start.add(config.cycleDuration);
    final deploymentEnd = config.endTime;
    if (deploymentEnd != null && !start.isBefore(deploymentEnd)) return null;

    final end =
        deploymentEnd != null && deploymentEnd.isBefore(plannedEnd)
            ? deploymentEnd
            : plannedEnd;
    if (!end.isAfter(start)) return null;

    return AruCycleWindow(
      index: windowIndex,
      start: start,
      end: end,
      plannedEnd: plannedEnd,
    );
  }

  bool _isAllowedStart(DateTime start) {
    final sunTimes = estimateAruSunTimes(
      date: start,
      latitude: config.latitude,
      longitude: config.longitude,
    );

    return switch (config.dielPattern) {
      AruDielPattern.anyTime => true,
      AruDielPattern.dayOnly =>
        !start.isBefore(sunTimes.sunrise) && start.isBefore(sunTimes.sunset),
      AruDielPattern.nightOnly =>
        start.isBefore(sunTimes.sunrise) || !start.isBefore(sunTimes.sunset),
      AruDielPattern.aroundSunrise => _isInWindow(
        start,
        sunTimes.sunrise.subtract(const Duration(hours: 1)),
        sunTimes.sunrise.add(const Duration(hours: 1)),
      ),
      AruDielPattern.aroundSunset => _isInWindow(
        start,
        sunTimes.sunset.subtract(const Duration(hours: 1)),
        sunTimes.sunset.add(const Duration(hours: 1)),
      ),
    };
  }

  bool _isInWindow(DateTime time, DateTime start, DateTime end) {
    return !time.isBefore(start) && time.isBefore(end);
  }
}
