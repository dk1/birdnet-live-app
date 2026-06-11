import 'dart:convert';

import 'package:birdnet_live/features/aru/aru_schedule.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 6, 1, 4);
  final settings = SessionSettings(
    windowDuration: 3,
    confidenceThreshold: 35,
    inferenceRate: 1.0,
    speciesFilterMode: 'off',
  );

  group('AruCycleMetadata', () {
    test('round-trips populated cycle metadata', () {
      final cycle = AruCycleMetadata(
        index: 2,
        plannedStart: start.add(const Duration(hours: 2)),
        plannedEnd: start.add(const Duration(hours: 2, minutes: 10)),
        actualStart: start.add(const Duration(hours: 2, seconds: 3)),
        actualEnd: start.add(const Duration(hours: 2, minutes: 9)),
        status: AruCycleStatus.partial,
        recordingPath: '/recordings/aru/cycle_002.flac',
        detectionCount: 12,
        retainedClipCount: 5,
        droppedClipCount: 7,
        note: 'Low storage warning during cycle.',
      );

      final restored = AruCycleMetadata.fromJson(cycle.toJson());

      expect(restored.index, 2);
      expect(
        restored.plannedStart.isAtSameMomentAs(cycle.plannedStart),
        isTrue,
      );
      expect(restored.plannedEnd.isAtSameMomentAs(cycle.plannedEnd), isTrue);
      expect(
        restored.actualStart!.isAtSameMomentAs(cycle.actualStart!),
        isTrue,
      );
      expect(restored.actualEnd!.isAtSameMomentAs(cycle.actualEnd!), isTrue);
      expect(restored.status, AruCycleStatus.partial);
      expect(restored.recordingPath, '/recordings/aru/cycle_002.flac');
      expect(restored.detectionCount, 12);
      expect(restored.retainedClipCount, 5);
      expect(restored.droppedClipCount, 7);
      expect(restored.note, 'Low storage warning during cycle.');
    });

    test('omits default cycle fields', () {
      final cycle = AruCycleMetadata(
        index: 0,
        plannedStart: start,
        plannedEnd: start.add(const Duration(minutes: 10)),
      );

      final json = cycle.toJson();

      expect(json.containsKey('status'), isFalse);
      expect(json.containsKey('detectionCount'), isFalse);
      expect(json.containsKey('retainedClipCount'), isFalse);
      expect(json.containsKey('droppedClipCount'), isFalse);
    });
  });

  group('AruDeploymentMetadata', () {
    test('round-trips schedule and cycle metadata', () {
      final metadata = AruDeploymentMetadata(
        deploymentName: 'Dawn Station',
        stationId: 'ARU-07',
        scheduleStart: start,
        cycleDurationSeconds: 600,
        repeatIntervalSeconds: 3600,
        scheduleEnd: start.add(const Duration(days: 2)),
        maxCycles: 12,
        lowBatteryStopPercent: 15,
        dielPattern: AruDielPattern.anyTime,
        latitude: 52.52,
        longitude: 13.405,
        recordingFormat: 'wav',
        testCycleEnabled: true,
        cycles: [
          AruCycleMetadata(
            index: 0,
            plannedStart: start,
            plannedEnd: start.add(const Duration(minutes: 10)),
            actualStart: start,
            actualEnd: start.add(const Duration(minutes: 10)),
            status: AruCycleStatus.completed,
            recordingPath: '/recordings/aru/cycle_000.flac',
            detectionCount: 3,
          ),
        ],
      );

      final restored = AruDeploymentMetadata.fromJson(metadata.toJson());

      expect(restored.deploymentName, 'Dawn Station');
      expect(restored.stationId, 'ARU-07');
      expect(restored.scheduleStart.isAtSameMomentAs(start), isTrue);
      expect(restored.cycleDurationSeconds, 600);
      expect(restored.repeatIntervalSeconds, 3600);
      expect(
        restored.scheduleEnd!.isAtSameMomentAs(
          start.add(const Duration(days: 2)),
        ),
        isTrue,
      );
      expect(restored.maxCycles, 12);
      expect(restored.lowBatteryStopPercent, 15);
      expect(restored.latitude, 52.52);
      expect(restored.longitude, 13.405);
      expect(restored.recordingFormat, 'wav');
      expect(restored.testCycleEnabled, isTrue);
      expect(restored.cycles.single.status, AruCycleStatus.completed);

      final schedule = restored.toScheduleConfig();
      expect(schedule.startTime.isAtSameMomentAs(start), isTrue);
      expect(schedule.cycleDuration, const Duration(minutes: 10));
      expect(schedule.repeatInterval, const Duration(hours: 1));
      expect(schedule.maxCycles, 12);
      expect(schedule.latitude, 52.52);
      expect(schedule.longitude, 13.405);
    });
  });

  group('LiveSession ARU metadata', () {
    test('round-trips ARU metadata through session JSON', () {
      final session = LiveSession(
        id: 'aru-session',
        type: SessionType.aru,
        startTime: start,
        settings: settings,
        aruMetadata: AruDeploymentMetadata(
          deploymentName: 'Dawn Station',
          stationId: 'ARU-07',
          scheduleStart: start,
          cycleDurationSeconds: 600,
          repeatIntervalSeconds: 3600,
          maxCycles: 2,
          cycles: [
            AruCycleMetadata(
              index: 0,
              plannedStart: start,
              plannedEnd: start.add(const Duration(minutes: 10)),
              status: AruCycleStatus.completed,
            ),
          ],
        ),
      );

      final decoded =
          jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>;
      final restored = LiveSession.fromJson(decoded);

      expect(decoded['type'], 'aru');
      expect(decoded.containsKey('aru'), isTrue);
      expect(restored.type, SessionType.aru);
      expect(restored.aruMetadata?.deploymentName, 'Dawn Station');
      expect(restored.aruMetadata?.cycles.single.index, 0);
    });

    test('omits ARU metadata for sessions without it', () {
      final session = LiveSession(
        id: 'live-session',
        startTime: start,
        settings: settings,
      );

      final json = session.toJson();

      expect(json.containsKey('aru'), isFalse);
      expect(LiveSession.fromJson(json).aruMetadata, isNull);
    });
  });
}
