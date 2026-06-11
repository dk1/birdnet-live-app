// =============================================================================
// ARU Storage Estimator - Pure helpers for deployment readiness checks
// =============================================================================

import '../recording/recording_service.dart';
import 'aru_defaults.dart';
import 'aru_schedule.dart';

/// Input values for ARU storage estimation.
class AruStorageEstimateInput {
  const AruStorageEstimateInput({
    required this.schedule,
    required this.recordingMode,
    this.format = 'flac',
    this.sampleRate = 32000,
    this.channels = 1,
    this.bitsPerSample = 16,
    this.flacCompressionRatio = 0.55,
    this.expectedRetainedClips,
    this.clipDurationSeconds = 5,
  });

  final AruScheduleConfig schedule;
  final RecordingMode recordingMode;
  final String format;
  final int sampleRate;
  final int channels;
  final int bitsPerSample;

  /// Estimated FLAC bytes divided by WAV bytes.
  ///
  /// Real field recordings vary widely, so this must be shown as an estimate.
  final double flacCompressionRatio;

  /// Optional retained clip count for detection-only deployments.
  final int? expectedRetainedClips;

  /// Expected length of each retained clip.
  final int clipDurationSeconds;
}

/// Storage estimate for an ARU deployment.
class AruStorageEstimate {
  const AruStorageEstimate({
    required this.bytesPerRecordedSecond,
    required this.bytesPerHour,
    required this.bytesPerDayAtFullDuty,
    required this.bytesPerScheduledDay,
    this.totalBytes,
    this.totalRecordedDuration,
    this.totalCycles,
  });

  /// Estimated bytes for one second of retained audio.
  final int bytesPerRecordedSecond;

  /// Estimated bytes for one hour of retained audio.
  final int bytesPerHour;

  /// Estimated bytes for 24 hours of retained audio.
  final int bytesPerDayAtFullDuty;

  /// Estimated bytes for the first scheduled 24-hour deployment period.
  final int bytesPerScheduledDay;

  /// Estimated total bytes, or null for open-ended deployments.
  final int? totalBytes;

  /// Estimated retained/recorded audio duration, or null when open-ended.
  final Duration? totalRecordedDuration;

  /// Estimated number of scheduled cycles, or null when open-ended.
  final int? totalCycles;

  bool get hasFiniteTotal => totalBytes != null;
}

/// Computes storage estimates without touching platform storage APIs.
class AruStorageEstimator {
  const AruStorageEstimator();

  AruStorageEstimate estimate(AruStorageEstimateInput input) {
    input.schedule.validateOrThrow();

    final bytesPerSecond = _bytesPerSecond(input);
    final bytesPerHour = bytesPerSecond * 3600;
    final bytesPerDay = bytesPerHour * 24;
    final scheduledBytesPerDay = _scheduledDayBytes(
      input.schedule,
      bytesPerSecond,
    );

    if (input.recordingMode == RecordingMode.off) {
      return const AruStorageEstimate(
        bytesPerRecordedSecond: 0,
        bytesPerHour: 0,
        bytesPerDayAtFullDuty: 0,
        bytesPerScheduledDay: 0,
        totalBytes: 0,
        totalRecordedDuration: Duration.zero,
        totalCycles: 0,
      );
    }

    if (input.recordingMode == RecordingMode.detectionsOnly) {
      final clips = input.expectedRetainedClips;
      if (clips == null) {
        return AruStorageEstimate(
          bytesPerRecordedSecond: bytesPerSecond,
          bytesPerHour: bytesPerHour,
          bytesPerDayAtFullDuty: bytesPerDay,
          bytesPerScheduledDay: scheduledBytesPerDay,
        );
      }
      final seconds = clips * input.clipDurationSeconds;
      return AruStorageEstimate(
        bytesPerRecordedSecond: bytesPerSecond,
        bytesPerHour: bytesPerHour,
        bytesPerDayAtFullDuty: bytesPerDay,
        bytesPerScheduledDay: scheduledBytesPerDay,
        totalBytes: seconds * bytesPerSecond,
        totalRecordedDuration: Duration(seconds: seconds),
      );
    }

    final active = _finiteActiveDuration(input.schedule);
    if (active == null) {
      return AruStorageEstimate(
        bytesPerRecordedSecond: bytesPerSecond,
        bytesPerHour: bytesPerHour,
        bytesPerDayAtFullDuty: bytesPerDay,
        bytesPerScheduledDay: scheduledBytesPerDay,
      );
    }

    final totalSeconds = active.duration.inSeconds;
    return AruStorageEstimate(
      bytesPerRecordedSecond: bytesPerSecond,
      bytesPerHour: bytesPerHour,
      bytesPerDayAtFullDuty: bytesPerDay,
      bytesPerScheduledDay: scheduledBytesPerDay,
      totalBytes: totalSeconds * bytesPerSecond,
      totalRecordedDuration: active.duration,
      totalCycles: active.cycles,
    );
  }

  /// Whether [availableBytes] can hold [requiredBytes] plus a safety margin.
  bool hasEnoughStorage({
    required int availableBytes,
    required int requiredBytes,
    int safetyMarginBytes = AruDefaults.defaultStorageSafetyMarginBytes,
  }) {
    if (requiredBytes < 0 || availableBytes < 0 || safetyMarginBytes < 0) {
      return false;
    }
    return availableBytes >= requiredBytes + safetyMarginBytes;
  }

  int _bytesPerSecond(AruStorageEstimateInput input) {
    final wavBytes =
        input.sampleRate * input.channels * (input.bitsPerSample ~/ 8);
    if (input.format.toLowerCase() != 'flac') return wavBytes;
    return (wavBytes * input.flacCompressionRatio).ceil();
  }

  int _scheduledDayBytes(AruScheduleConfig schedule, int bytesPerSecond) {
    final start = schedule.startTime;
    final end = start.add(const Duration(days: 1));
    final daySchedule = AruScheduleConfig(
      startTime: start,
      cycleDuration: schedule.cycleDuration,
      repeatInterval: schedule.repeatInterval,
      endTime:
          schedule.endTime != null && schedule.endTime!.isBefore(end)
              ? schedule.endTime
              : end,
      lowBatteryStopPercent: schedule.lowBatteryStopPercent,
      dielPattern: schedule.dielPattern,
      testCycleEnabled: schedule.testCycleEnabled,
      latitude: schedule.latitude,
      longitude: schedule.longitude,
    );
    final active = _finiteActiveDuration(daySchedule);
    return (active?.duration.inSeconds ?? 0) * bytesPerSecond;
  }

  _FiniteActiveDuration? _finiteActiveDuration(AruScheduleConfig schedule) {
    if (schedule.maxCycles == null && schedule.endTime == null) return null;

    var cycles = 0;
    var duration = Duration.zero;
    final calculator = AruScheduleCalculator(schedule);
    var windows = calculator.nextWindows(schedule.startTime, count: 1000);

    while (windows.isNotEmpty) {
      for (final window in windows) {
        cycles++;
        duration += window.end.difference(window.start);
      }
      if (windows.length < 1000) break;
      final nextStart = windows.last.end.add(const Duration(microseconds: 1));
      windows = calculator.nextWindows(nextStart, count: 1000);
    }

    return _FiniteActiveDuration(cycles: cycles, duration: duration);
  }
}

class _FiniteActiveDuration {
  const _FiniteActiveDuration({required this.cycles, required this.duration});

  final int cycles;
  final Duration duration;
}
