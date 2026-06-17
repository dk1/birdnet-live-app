import 'package:birdnet_live/features/aru/aru_controller.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/recording/recording_service.dart';
import 'package:birdnet_live/features/survey/detection_sampler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 6, 1, 4);
  final settings = SessionSettings(
    windowDuration: 3,
    confidenceThreshold: 35,
    inferenceRate: 1.0,
    speciesFilterMode: 'off',
  );

  AruDeploymentMetadata metadata({
    int maxCycles = 2,
    String recordingMode = 'full',
    String samplingMode = 'smart',
    int topNPerSpecies = 10,
  }) {
    return AruDeploymentMetadata(
      deploymentName: 'Dawn Station',
      stationId: 'ARU-07',
      scheduleStart: start,
      eachCycleIsSession: false,
      cycleDurationSeconds: 600,
      repeatIntervalSeconds: 3600,
      maxCycles: maxCycles,
      recordingMode: recordingMode,
      samplingMode: samplingMode,
      topNPerSpecies: topNPerSpecies,
      cycles: [],
    );
  }

  group('AruController', () {
    test('starts a deployment and persists initial waiting state', () async {
      final saved = <LiveSession>[];
      final controller = AruController(
        saveSession: (session) async => saved.add(session),
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
        observerName: 'Jane',
        latitude: 52.52,
        longitude: 13.405,
      );

      expect(controller.state, AruControllerState.waiting);
      expect(controller.session?.type, SessionType.aru);
      expect(controller.session?.observerName, 'Jane');
      expect(controller.session?.latitude, 52.52);
      expect(controller.session?.customName, 'Dawn Station - ARU-07');
      expect(controller.session?.aruMetadata?.stationId, 'ARU-07');
      expect(saved.length, 2);
    });

    test(
      'uses station ID as session name when deployment name is empty',
      () async {
        final controller = AruController(
          saveSession: (session) async {},
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: AruDeploymentMetadata(
            stationId: 'ARU-09',
            scheduleStart: start,
            eachCycleIsSession: false,
            cycleDurationSeconds: 600,
            repeatIntervalSeconds: 3600,
            maxCycles: 1,
          ),
        );

        expect(controller.session?.customName, 'ARU-09');
      },
    );

    test('enters recording state inside a scheduled cycle', () async {
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));

      final session = controller.session!;
      final cycle = session.aruMetadata!.cycles.single;

      expect(controller.state, AruControllerState.recording);
      expect(session.segments.length, 1);
      expect(session.segments.single.startTime, start);
      expect(cycle.index, 0);
      expect(cycle.status, AruCycleStatus.recording);
      expect(cycle.actualStart, start);
    });

    test('restores an unfinished deployment and resumes scheduling', () async {
      final saved = <LiveSession>[];
      final session = LiveSession(
        id: 'aru-restore',
        type: SessionType.aru,
        startTime: start,
        settings: settings,
        aruMetadata: metadata(maxCycles: 2),
      );
      final controller = AruController(
        saveSession: (session) async => saved.add(session),
        now: () => start.add(const Duration(minutes: 5)),
      );

      await controller.restoreDeployment(session);

      expect(controller.state, AruControllerState.recording);
      expect(controller.session?.id, 'aru-restore');
      expect(controller.session?.aruMetadata?.cycles.single.index, 0);
      expect(
        controller.session?.aruMetadata?.cycles.single.status,
        AruCycleStatus.recording,
      );
      expect(saved, isNotEmpty);
    });

    test('marks stale recording cycles partial during restore', () async {
      final session = LiveSession(
        id: 'aru-restore',
        type: SessionType.aru,
        startTime: start,
        settings: settings,
        aruMetadata: metadata(maxCycles: 2)
          ..cycles.add(
            AruCycleMetadata(
              index: 0,
              plannedStart: start,
              plannedEnd: start.add(const Duration(minutes: 10)),
              actualStart: start,
              status: AruCycleStatus.recording,
              recordingPath: '/recordings/aru/cycle_0.flac',
            ),
          ),
      );
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.add(const Duration(minutes: 30)),
      );

      await controller.restoreDeployment(session);

      final cycle = controller.session!.aruMetadata!.cycles.single;
      expect(controller.state, AruControllerState.waiting);
      expect(cycle.status, AruCycleStatus.partial);
      expect(cycle.actualEnd, start.add(const Duration(minutes: 10)));
      expect(cycle.recordingPath, '/recordings/aru/cycle_0.flac');
    });

    test('finalizes a late cycle at planned end, not wakeup time', () async {
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));
      await controller.evaluate(now: start.add(const Duration(minutes: 30)));

      final session = controller.session!;
      final cycle = session.aruMetadata!.cycles.single;

      expect(controller.state, AruControllerState.waiting);
      expect(cycle.status, AruCycleStatus.completed);
      expect(cycle.actualEnd, start.add(const Duration(minutes: 10)));
      expect(
        session.segments.single.endTime,
        start.add(const Duration(minutes: 10)),
      );
      expect(session.recordedDurationSeconds, 600);
    });

    test('starts the next cycle and keeps cycle metadata sorted', () async {
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));
      await controller.evaluate(
        now: start.add(const Duration(hours: 1, minutes: 1)),
      );

      final cycles = controller.session!.aruMetadata!.cycles;

      expect(controller.state, AruControllerState.recording);
      expect(cycles.map((c) => c.index), <int>[0, 1]);
      expect(cycles.first.status, AruCycleStatus.completed);
      expect(cycles.last.status, AruCycleStatus.recording);
      expect(controller.session!.segments.length, 2);
    });

    test('runs optional sanity check cycle immediately', () async {
      final deployedAt = DateTime.utc(2026, 6, 1, 4, 17);
      final controller = AruController(
        saveSession: (session) async {},
        now: () => deployedAt,
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: AruDeploymentMetadata(
          scheduleStart: deployedAt,
          eachCycleIsSession: false,
          cycleDurationSeconds: 600,
          repeatIntervalSeconds: 3600,
          maxCycles: 1,
          testCycleEnabled: true,
        ),
      );

      expect(controller.state, AruControllerState.recording);
      expect(controller.session!.segments.single.startTime, deployedAt);
      expect(
        controller.session!.aruMetadata!.cycles.single.plannedEnd,
        deployedAt.add(const Duration(minutes: 1)),
      );
    });

    test('completes after the final configured cycle', () async {
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(maxCycles: 1),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));
      await controller.evaluate(now: start.add(const Duration(hours: 1)));

      expect(controller.state, AruControllerState.completed);
      expect(controller.session!.endTime, start.add(const Duration(hours: 1)));
      expect(
        controller.session!.aruMetadata!.cycles.single.status,
        AruCycleStatus.completed,
      );
    });

    test('manual stop closes active cycle as stopped', () async {
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));
      final stopped = await controller.stop(
        now: start.add(const Duration(minutes: 7)),
      );

      expect(controller.state, AruControllerState.completed);
      expect(stopped.stopReason, SessionStopReason.manual);
      expect(stopped.endTime, start.add(const Duration(minutes: 7)));
      expect(stopped.recordedDurationSeconds, 7 * 60);
      expect(stopped.aruMetadata!.cycles.single.status, AruCycleStatus.stopped);
      expect(
        stopped.aruMetadata!.cycles.single.actualEnd,
        start.add(const Duration(minutes: 7)),
      );
    });

    test(
      'starts and stops cycle recording hooks at schedule boundaries',
      () async {
        final events = <String>[];
        final controller = AruController(
          saveSession: (session) async {},
          startCycleRecording: (session, window) async {
            events.add('start:${window.index}');
            return '/recordings/aru/cycle_${window.index}.flac';
          },
          stopCycleRecording: (session, cycle, endedAt) async {
            events.add('stop:${cycle.index}:${endedAt.toIso8601String()}');
            return '${cycle.recordingPath}.closed';
          },
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(),
        );
        await controller.evaluate(now: start.add(const Duration(minutes: 5)));
        await controller.evaluate(now: start.add(const Duration(minutes: 30)));

        final cycle = controller.session!.aruMetadata!.cycles.single;
        expect(events, [
          'start:0',
          'stop:0:${start.add(const Duration(minutes: 10)).toIso8601String()}',
        ]);
        expect(cycle.recordingPath, '/recordings/aru/cycle_0.flac.closed');
        // Combined deployments stay clips-only: per-cycle audio lives on the
        // cycle metadata, and the aggregate session must not claim a single
        // recordingPath that would point at only the last cycle.
        expect(controller.session!.recordingPath, isNull);
        expect(cycle.status, AruCycleStatus.completed);
      },
    );

    test('does not start cycle recording hook when recording is off', () async {
      var starts = 0;
      final controller = AruController(
        saveSession: (session) async {},
        startCycleRecording: (session, window) async {
          starts++;
          return '/recordings/aru/cycle_${window.index}.flac';
        },
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(recordingMode: RecordingMode.off.name),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));

      expect(starts, 0);
      expect(
        controller.session!.aruMetadata!.cycles.single.recordingPath,
        isNull,
      );
    });

    test(
      'syncDetections saves detection clips and updates cycle counts',
      () async {
        final savedClips = <String>[];
        final controller = AruController(
          saveSession: (session) async {},
          saveDetectionClip: (session, record) async {
            final path = '/recordings/${record.scientificName}.flac';
            savedClips.add(path);
            return path;
          },
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(recordingMode: RecordingMode.detectionsOnly.name),
        );
        await controller.evaluate(now: start.add(const Duration(minutes: 1)));

        final detectedAt = start.add(const Duration(minutes: 2));
        final open = DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.6,
          timestamp: detectedAt,
        );
        final closed = DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.8,
          timestamp: detectedAt,
          endTimestamp: detectedAt.add(const Duration(seconds: 20)),
        );

        await controller.syncDetections([open]);
        await controller.syncDetections([closed]);

        final session = controller.session!;
        final cycle = session.aruMetadata!.cycles.single;
        expect(savedClips, ['/recordings/Turdus merula.flac']);
        expect(session.detections, hasLength(1));
        expect(session.detections.single.confidence, 0.8);
        expect(session.detections.single.endTimestamp, closed.endTimestamp);
        expect(session.detections.single.audioClipPath, savedClips.single);
        expect(cycle.detectionCount, 1);
        expect(cycle.retainedClipCount, 1);
        expect(cycle.droppedClipCount, 0);
      },
    );

    test(
      'syncDetections keeps saved clip paths attached to their timestamps',
      () async {
        final controller = AruController(
          saveSession: (session) async {},
          saveDetectionClip: (session, record) async {
            final timestamp = record.timestamp.toUtc().millisecondsSinceEpoch;
            return '/recordings/clip_$timestamp.flac';
          },
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(
            maxCycles: 3,
            recordingMode: RecordingMode.detectionsOnly.name,
            samplingMode: SamplingMode.smart.name,
            topNPerSpecies: 1,
          ),
        );

        await controller.evaluate(now: start.add(const Duration(minutes: 1)));
        final firstAt = start.add(const Duration(minutes: 2));
        await controller.syncDetections([
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.8,
            timestamp: firstAt,
          ),
        ]);
        await controller.syncDetections([
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.9,
            timestamp: firstAt,
            endTimestamp: firstAt.add(const Duration(seconds: 20)),
          ),
        ]);

        await controller.evaluate(now: start.add(const Duration(minutes: 30)));
        await controller.evaluate(
          now: start.add(const Duration(hours: 1, minutes: 1)),
        );
        final secondAt = start.add(const Duration(hours: 1, minutes: 2));
        await controller.syncDetections([
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.95,
            timestamp: secondAt,
            endTimestamp: secondAt.add(const Duration(seconds: 20)),
          ),
        ]);

        final detections = controller.session!.detections;
        expect(detections, hasLength(2));
        for (final detection in detections) {
          final expectedTimestamp =
              detection.timestamp.toUtc().millisecondsSinceEpoch;
          if (detection.audioClipPath == null) continue;
          expect(detection.audioClipPath, contains('$expectedTimestamp'));
        }
        expect(
          detections.where((detection) => detection.audioClipPath != null),
          hasLength(1),
        );
        expect(detections.first.audioClipPath, isNull);
        expect(
          detections.last.audioClipPath,
          contains('${secondAt.toUtc().millisecondsSinceEpoch}'),
        );
      },
    );

    test(
      'smart clip sampling spreads each species across ARU cycles in one session',
      () async {
        final controller = AruController(
          saveSession: (session) async {},
          saveDetectionClip: (session, record) async {
            final timestamp = record.timestamp.toUtc().millisecondsSinceEpoch;
            final species = record.scientificName.replaceAll(' ', '_');
            return '/recordings/clip_${timestamp}_$species.flac';
          },
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(
            maxCycles: 3,
            recordingMode: RecordingMode.detectionsOnly.name,
            samplingMode: SamplingMode.smart.name,
            topNPerSpecies: 2,
          ),
        );

        await controller.evaluate(now: start.add(const Duration(minutes: 1)));
        final cycle0Low = start.add(const Duration(minutes: 2));
        final cycle0Mid = start.add(const Duration(minutes: 3));
        await controller.syncDetections([
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.4,
            timestamp: cycle0Low,
            endTimestamp: cycle0Low.add(const Duration(seconds: 20)),
          ),
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.5,
            timestamp: cycle0Mid,
            endTimestamp: cycle0Mid.add(const Duration(seconds: 20)),
          ),
        ]);

        await controller.evaluate(now: start.add(const Duration(minutes: 30)));
        await controller.evaluate(
          now: start.add(const Duration(hours: 1, minutes: 1)),
        );
        final cycle1 = start.add(const Duration(hours: 1, minutes: 2));
        await controller.syncDetections([
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.6,
            timestamp: cycle1,
            endTimestamp: cycle1.add(const Duration(seconds: 20)),
          ),
          DetectionRecord(
            scientificName: 'Erithacus rubecula',
            commonName: 'European Robin',
            confidence: 0.3,
            timestamp: cycle1.add(const Duration(minutes: 1)),
            endTimestamp: cycle1.add(const Duration(minutes: 1, seconds: 20)),
          ),
        ]);

        final detections = controller.session!.detections;
        final retainedBlackbirds =
            detections
                .where(
                  (detection) =>
                      detection.scientificName == 'Turdus merula' &&
                      detection.audioClipPath != null,
                )
                .toList();
        final retainedRobin =
            detections
                .where(
                  (detection) =>
                      detection.scientificName == 'Erithacus rubecula' &&
                      detection.audioClipPath != null,
                )
                .toList();

        expect(retainedBlackbirds, hasLength(2));
        expect(
          retainedBlackbirds.map((detection) => detection.timestamp),
          containsAll([cycle0Mid, cycle1]),
        );
        expect(
          detections
              .singleWhere((detection) => detection.timestamp == cycle0Low)
              .audioClipPath,
          isNull,
        );
        expect(retainedRobin, hasLength(1));
      },
    );

    test(
      'saves a separate session per cycle and keeps no aggregate when '
      'eachCycleIsSession is true',
      () async {
        final store = <String, LiveSession>{};
        final controller = AruController(
          saveSession: (session) async => store[session.id] = session,
          discardSession: (sessionId) async => store.remove(sessionId),
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: AruDeploymentMetadata(
            deploymentName: 'eBird plot',
            scheduleStart: start,
            cycleDurationSeconds: 600,
            repeatIntervalSeconds: 3600,
            maxCycles: 3,
            eachCycleIsSession: true,
          ),
          sessionNumber: 12,
        );

        // Enter and leave cycles 0, 1, and 2.
        await controller.evaluate(now: start.add(const Duration(minutes: 5)));
        await controller.evaluate(now: start.add(const Duration(minutes: 30)));
        await controller.evaluate(
          now: start.add(const Duration(hours: 1, minutes: 5)),
        );
        await controller.evaluate(
          now: start.add(const Duration(hours: 1, minutes: 30)),
        );
        await controller.evaluate(
          now: start.add(const Duration(hours: 2, minutes: 5)),
        );
        await controller.evaluate(
          now: start.add(const Duration(hours: 2, minutes: 30)),
        );

        // Only the per-cycle sessions remain; the aggregate (full-audio mode
        // included) is discarded so it never lingers in the library.
        final cycleSessions =
            store.values.where((s) => s.id.contains('_cycle_')).toList();
        final aggregateSessions =
            store.values.where((s) => !s.id.contains('_cycle_')).toList();
        expect(aggregateSessions, isEmpty);
        expect(cycleSessions, hasLength(3));
        expect(cycleSessions.first.id, 'aru-1_cycle_0');
        expect(cycleSessions.first.sessionNumber, 12);
        expect(cycleSessions.first.customName, 'eBird plot - Cycle 1');
        expect(cycleSessions.last.id, 'aru-1_cycle_2');
        expect(cycleSessions.last.sessionNumber, 12);
        expect(cycleSessions.last.customName, 'eBird plot - Cycle 3');
        expect(cycleSessions.first.startTime, start);
        expect(
          cycleSessions.first.endTime,
          start.add(const Duration(minutes: 10)),
        );
        expect(cycleSessions.first.aruMetadata, isNotNull);
        expect(cycleSessions.first.aruMetadata!.cycles.single.index, 0);
        expect(
          cycleSessions.first.aruMetadata!.cycles.single.status,
          AruCycleStatus.completed,
        );
        expect(cycleSessions.first.aruMetadata!.eachCycleIsSession, isTrue);
        expect(controller.reviewSession, cycleSessions.last);
      },
    );

    test(
      'does not persist aggregate session for clip-only per-cycle deployment',
      () async {
        final store = <String, LiveSession>{};
        final discarded = <String>[];
        final controller = AruController(
          saveSession: (session) async => store[session.id] = session,
          discardSession: (sessionId) async {
            discarded.add(sessionId);
            store.remove(sessionId);
          },
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: AruDeploymentMetadata(
            deploymentName: 'eBird plot',
            scheduleStart: start,
            cycleDurationSeconds: 600,
            repeatIntervalSeconds: 3600,
            maxCycles: 1,
            recordingMode: RecordingMode.detectionsOnly.name,
            eachCycleIsSession: true,
          ),
          sessionNumber: 12,
        );

        await controller.evaluate(now: start.add(const Duration(minutes: 5)));
        await controller.syncDetections([
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.8,
            timestamp: start.add(const Duration(minutes: 6)),
          ),
        ]);
        await controller.evaluate(now: start.add(const Duration(minutes: 30)));
        await controller.evaluate(now: start.add(const Duration(hours: 2)));

        final cycleSessions =
            store.values.where((s) => s.id.contains('_cycle_')).toList();
        final aggregateSessions =
            store.values.where((s) => !s.id.contains('_cycle_')).toList();
        expect(cycleSessions, hasLength(1));
        expect(cycleSessions.single.id, 'aru-1_cycle_0');
        expect(cycleSessions.single.detections, hasLength(1));
        expect(aggregateSessions, isEmpty);
        expect(discarded, ['aru-1']);
        expect(controller.reviewSession, cycleSessions.single);
      },
    );

    test(
      'has no review session when a clip-only per-cycle deployment is stopped '
      'before any cycle completes',
      () async {
        final saved = <LiveSession>[];
        final discarded = <String>[];
        final controller = AruController(
          saveSession: (session) async => saved.add(session),
          discardSession: (sessionId) async => discarded.add(sessionId),
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: AruDeploymentMetadata(
            deploymentName: 'eBird plot',
            scheduleStart: start,
            cycleDurationSeconds: 600,
            repeatIntervalSeconds: 3600,
            maxCycles: 1,
            recordingMode: RecordingMode.detectionsOnly.name,
            eachCycleIsSession: true,
          ),
          sessionNumber: 12,
        );

        // Stop while still in the initial waiting window (the first cycle has
        // not started, so no per-cycle session exists yet).
        await controller.stop(
          now: start.subtract(const Duration(minutes: 1)),
        );

        final cycleSessions =
            saved.where((s) => s.id.contains('_cycle_')).toList();
        expect(cycleSessions, isEmpty);
        expect(discarded, ['aru-1']);
        // The aggregate was discarded, so review must not open it.
        expect(controller.reviewSession, isNull);
      },
    );

    test('names per-cycle test run from deployment name', () async {
      final saved = <LiveSession>[];
      final controller = AruController(
        saveSession: (session) async => saved.add(session),
        now: () => start,
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: AruDeploymentMetadata(
          deploymentName: 'test',
          scheduleStart: start,
          cycleDurationSeconds: 600,
          repeatIntervalSeconds: 3600,
          maxCycles: 1,
          testCycleEnabled: true,
          eachCycleIsSession: true,
        ),
        sessionNumber: 12,
      );

      await controller.evaluate(now: start.add(const Duration(minutes: 2)));
      await controller.evaluate(
        now: start.add(const Duration(hours: 1, minutes: 5)),
      );
      await controller.evaluate(
        now: start.add(const Duration(hours: 1, minutes: 30)),
      );

      final cycleSessions =
          saved.where((s) => s.id.contains('_cycle_')).toList();
      expect(cycleSessions, hasLength(2));
      expect(cycleSessions.first.id, 'aru-1_cycle_0');
      expect(cycleSessions.first.customName, 'test - Test Run');
      expect(cycleSessions.last.id, 'aru-1_cycle_1');
      expect(cycleSessions.last.customName, 'test - Cycle 1');
    });

    test(
      'does not save per-cycle sessions when eachCycleIsSession is false',
      () async {
        final saved = <LiveSession>[];
        final controller = AruController(
          saveSession: (session) async => saved.add(session),
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(),
        );

        await controller.evaluate(now: start.add(const Duration(minutes: 5)));
        await controller.evaluate(now: start.add(const Duration(minutes: 30)));

        final cycleSessions =
            saved.where((s) => s.id.contains('_cycle_')).toList();
        expect(cycleSessions, isEmpty);
      },
    );

    test(
      'skips a scheduled cycle without recording when recording is suppressed',
      () async {
        var starts = 0;
        final controller = AruController(
          saveSession: (session) async {},
          startCycleRecording: (session, window) async {
            starts++;
            return '/recordings/aru/cycle_${window.index}.flac';
          },
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(),
        );
        await controller.evaluate(
          now: start.add(const Duration(minutes: 5)),
          recordingSuppressed: true,
        );

        final cycle = controller.session!.aruMetadata!.cycles.single;
        expect(controller.state, AruControllerState.waiting);
        expect(cycle.index, 0);
        expect(cycle.status, AruCycleStatus.skipped);
        expect(cycle.actualStart, isNull);
        expect(starts, 0);
        expect(controller.session!.segments, isEmpty);
      },
    );

    test(
      'does not re-record a window already skipped after battery recovers',
      () async {
        final controller = AruController(
          saveSession: (session) async {},
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(),
        );
        // Battery low at the start of cycle 0: skip it.
        await controller.evaluate(
          now: start.add(const Duration(minutes: 1)),
          recordingSuppressed: true,
        );
        // Battery recovers later in the same window: must not re-enter it.
        await controller.evaluate(
          now: start.add(const Duration(minutes: 5)),
        );

        final cycle = controller.session!.aruMetadata!.cycles.single;
        expect(controller.state, AruControllerState.waiting);
        expect(cycle.status, AruCycleStatus.skipped);
        expect(controller.session!.segments, isEmpty);
      },
    );

    test('records the next cycle once recording is no longer suppressed', () async {
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
      );
      // Cycle 0 skipped for low battery.
      await controller.evaluate(
        now: start.add(const Duration(minutes: 5)),
        recordingSuppressed: true,
      );
      // Cycle 1 records normally after recovery.
      await controller.evaluate(
        now: start.add(const Duration(hours: 1, minutes: 1)),
      );

      final cycles = controller.session!.aruMetadata!.cycles;
      expect(cycles.map((c) => c.index), <int>[0, 1]);
      expect(cycles.first.status, AruCycleStatus.skipped);
      expect(cycles.last.status, AruCycleStatus.recording);
      expect(controller.state, AruControllerState.recording);
      expect(controller.session!.segments, hasLength(1));
    });

    test('marks an in-progress cycle partial when battery drops mid-cycle', () async {
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
      );
      // Cycle 0 starts recording normally.
      await controller.evaluate(now: start.add(const Duration(minutes: 2)));
      // Battery drops mid-cycle: suppress recording.
      await controller.evaluate(
        now: start.add(const Duration(minutes: 5)),
        recordingSuppressed: true,
      );

      final cycle = controller.session!.aruMetadata!.cycles.single;
      expect(controller.state, AruControllerState.waiting);
      expect(cycle.status, AruCycleStatus.partial);
      expect(cycle.actualEnd, start.add(const Duration(minutes: 5)));
    });
  });
}
