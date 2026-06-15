import 'package:birdnet_live/features/aru/aru_schedule.dart';
import 'package:birdnet_live/features/aru/aru_storage_estimator.dart';
import 'package:birdnet_live/features/recording/recording_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 6, 1, 4);

  AruScheduleConfig schedule({
    DateTime? endTime,
    int? maxCycles,
    Duration cycleDuration = const Duration(minutes: 10),
    Duration repeatInterval = const Duration(hours: 1),
  }) {
    return AruScheduleConfig(
      startTime: start,
      cycleDuration: cycleDuration,
      repeatInterval: repeatInterval,
      endTime: endTime,
      maxCycles: maxCycles,
    );
  }

  group('AruStorageEstimator', () {
    const estimator = AruStorageEstimator();

    test('estimates finite WAV full-recording storage', () {
      final estimate = estimator.estimate(
        AruStorageEstimateInput(
          schedule: schedule(maxCycles: 3),
          recordingMode: RecordingMode.full,
          format: 'wav',
        ),
      );

      // WAV writer stores 16-bit mono PCM: 32000 * 2 = 64000 bytes/sec.
      expect(estimate.bytesPerRecordedSecond, 64000);
      expect(estimate.totalRecordedDuration, const Duration(minutes: 30));
      expect(estimate.totalCycles, 3);
      expect(estimate.totalBytes, 30 * 60 * 64000);
      expect(estimate.hasFiniteTotal, isTrue);
    });

    test('uses FLAC ratio for full-recording estimates', () {
      final estimate = estimator.estimate(
        AruStorageEstimateInput(
          schedule: schedule(maxCycles: 1),
          recordingMode: RecordingMode.full,
          format: 'flac',
          flacCompressionRatio: 0.5,
        ),
      );

      expect(estimate.bytesPerRecordedSecond, 32000);
      expect(estimate.totalBytes, 10 * 60 * 32000);
    });

    test('includes optional test cycle in full-recording estimates', () {
      final estimate = estimator.estimate(
        AruStorageEstimateInput(
          schedule: AruScheduleConfig(
            startTime: start,
            cycleDuration: const Duration(minutes: 10),
            repeatInterval: const Duration(hours: 1),
            maxCycles: 1,
            testCycleEnabled: true,
          ),
          recordingMode: RecordingMode.full,
          format: 'wav',
        ),
      );

      expect(estimate.totalRecordedDuration, const Duration(minutes: 11));
      expect(estimate.totalCycles, 2);
      expect(estimate.totalBytes, 11 * 60 * 64000);
    });

    test('estimates total cycles for date-time deployment ends', () {
      final cycles = estimator.estimateTotalCycles(
        schedule(
          endTime: start.add(const Duration(hours: 3, minutes: 5)),
          cycleDuration: const Duration(minutes: 30),
        ),
      );

      expect(cycles, 4);
    });

    test('includes optional test cycle in total cycle estimates', () {
      final cycles = estimator.estimateTotalCycles(
        AruScheduleConfig(
          startTime: start,
          cycleDuration: const Duration(minutes: 10),
          repeatInterval: const Duration(hours: 1),
          endTime: start.add(const Duration(hours: 1, minutes: 5)),
          testCycleEnabled: true,
        ),
      );

      expect(cycles, 2);
    });

    test('clamps active duration at schedule end', () {
      final estimate = estimator.estimate(
        AruStorageEstimateInput(
          schedule: schedule(
            endTime: start.add(const Duration(hours: 1, minutes: 5)),
            cycleDuration: const Duration(minutes: 30),
          ),
          recordingMode: RecordingMode.full,
          format: 'wav',
        ),
      );

      expect(estimate.totalCycles, 2);
      expect(estimate.totalRecordedDuration, const Duration(minutes: 35));
    });

    test('applies diel windows to finite storage estimates', () {
      final midnight = DateTime.utc(2026, 1, 1);
      final allDay = estimator.estimate(
        AruStorageEstimateInput(
          schedule: AruScheduleConfig(
            startTime: midnight,
            cycleDuration: const Duration(minutes: 10),
            repeatInterval: const Duration(hours: 1),
            endTime: midnight.add(const Duration(days: 1)),
          ),
          recordingMode: RecordingMode.full,
          format: 'wav',
        ),
      );
      final daylight = estimator.estimate(
        AruStorageEstimateInput(
          schedule: AruScheduleConfig(
            startTime: midnight,
            cycleDuration: const Duration(minutes: 10),
            repeatInterval: const Duration(hours: 1),
            endTime: midnight.add(const Duration(days: 1)),
            dielPattern: AruDielPattern.dayOnly,
          ),
          recordingMode: RecordingMode.full,
          format: 'wav',
        ),
      );

      expect(allDay.totalRecordedDuration, const Duration(hours: 4));
      expect(daylight.totalRecordedDuration, const Duration(hours: 2));
      expect(daylight.totalBytes, lessThan(allDay.totalBytes!));
    });

    test(
      'returns per-hour and per-day estimates for open-ended deployments',
      () {
        final estimate = estimator.estimate(
          AruStorageEstimateInput(
            schedule: schedule(),
            recordingMode: RecordingMode.full,
            format: 'wav',
          ),
        );

        expect(estimate.totalBytes, isNull);
        expect(estimate.totalRecordedDuration, isNull);
        expect(estimate.bytesPerHour, 64000 * 3600);
        expect(estimate.bytesPerDayAtFullDuty, 64000 * 3600 * 24);
        expect(estimate.bytesPerScheduledDay, 64000 * 3600 * 4);
        expect(estimate.hasFiniteTotal, isFalse);
      },
    );

    test('applies diel windows to open-ended per-day estimates', () {
      final midnight = DateTime.utc(2026, 1, 1);
      final estimate = estimator.estimate(
        AruStorageEstimateInput(
          schedule: AruScheduleConfig(
            startTime: midnight,
            cycleDuration: const Duration(minutes: 10),
            repeatInterval: const Duration(hours: 1),
            dielPattern: AruDielPattern.dayOnly,
          ),
          recordingMode: RecordingMode.full,
          format: 'wav',
        ),
      );

      expect(estimate.totalBytes, isNull);
      expect(estimate.bytesPerScheduledDay, 64000 * 3600 * 2);
      expect(
        estimate.bytesPerScheduledDay,
        lessThan(estimate.bytesPerDayAtFullDuty),
      );
    });

    test(
      'estimates long short-interval deployments without UI-scale stalls',
      () {
        final midnight = DateTime.utc(2026, 1, 1);
        final stopwatch = Stopwatch()..start();

        final estimate = estimator.estimate(
          AruStorageEstimateInput(
            schedule: AruScheduleConfig(
              startTime: midnight,
              cycleDuration: const Duration(seconds: 30),
              repeatInterval: const Duration(seconds: 30),
              endTime: midnight.add(const Duration(days: 365)),
              dielPattern: AruDielPattern.dayOnly,
            ),
            recordingMode: RecordingMode.full,
            format: 'wav',
          ),
        );

        stopwatch.stop();
        expect(estimate.totalBytes, isNotNull);
        expect(estimate.totalRecordedDuration, isNotNull);
        expect(estimate.totalCycles, greaterThan(100000));
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      },
    );

    test(
      'estimates detection-only clips when retained clip count is known',
      () {
        final estimate = estimator.estimate(
          AruStorageEstimateInput(
            schedule: schedule(maxCycles: 12),
            recordingMode: RecordingMode.detectionsOnly,
            format: 'wav',
            expectedRetainedClips: 20,
            clipDurationSeconds: 5,
          ),
        );

        expect(estimate.totalRecordedDuration, const Duration(seconds: 100));
        expect(estimate.totalBytes, 100 * 64000);
        expect(estimate.totalCycles, 12);
      },
    );

    test(
      'estimates detection-only finite clip storage from retained clips',
      () {
        final estimate = estimator.estimate(
          AruStorageEstimateInput(
            schedule: schedule(maxCycles: 3),
            recordingMode: RecordingMode.detectionsOnly,
            format: 'wav',
            clipDurationSeconds: 7,
            retainedClipsPerSpecies: 10,
            assumedSpeciesCount: 50,
          ),
        );

        expect(estimate.totalCycles, 3);
        expect(estimate.totalRecordedDuration, const Duration(minutes: 30));
        expect(estimate.totalBytes, 30 * 60 * 64000);
        expect(estimate.hasFiniteTotal, isTrue);
      },
    );

    test('estimates detection-only open-ended per-day clip storage', () {
      final estimate = estimator.estimate(
        AruStorageEstimateInput(
          schedule: schedule(),
          recordingMode: RecordingMode.detectionsOnly,
          format: 'wav',
          clipDurationSeconds: 5,
          retainedClipsPerSpecies: 10,
          assumedSpeciesCount: 50,
        ),
      );

      expect(estimate.totalBytes, isNull);
      expect(estimate.bytesPerHour, 2500 * 64000);
      expect(estimate.bytesPerScheduledDay, 2500 * 64000);
    });

    test('off mode reports zero storage', () {
      final estimate = estimator.estimate(
        AruStorageEstimateInput(
          schedule: schedule(maxCycles: 12),
          recordingMode: RecordingMode.off,
        ),
      );

      expect(estimate.totalBytes, 0);
      expect(estimate.totalRecordedDuration, Duration.zero);
      expect(estimate.bytesPerRecordedSecond, 0);
    });

    test('hasEnoughStorage includes safety margin', () {
      expect(
        estimator.hasEnoughStorage(
          availableBytes: 1000,
          requiredBytes: 800,
          safetyMarginBytes: 200,
        ),
        isTrue,
      );
      expect(
        estimator.hasEnoughStorage(
          availableBytes: 999,
          requiredBytes: 800,
          safetyMarginBytes: 200,
        ),
        isFalse,
      );
    });
  });
}
