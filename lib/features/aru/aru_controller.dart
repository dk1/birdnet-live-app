// =============================================================================
// ARU Controller - Pure state machine skeleton for scheduled deployments
// =============================================================================

import '../live/live_session.dart';
import '../recording/recording_service.dart';
import '../survey/detection_sampler.dart';
import 'aru_detection_sampler.dart';
import 'aru_schedule.dart';

/// Lifecycle state of an ARU deployment.
enum AruControllerState {
  idle,
  preparing,
  waiting,
  recording,
  finalizingCycle,
  recovering,
  stopping,
  completed,
  error,
}

/// Persists an ARU session after a state transition.
typedef AruSessionSaver = Future<void> Function(LiveSession session);

/// Deletes a saved ARU session record without touching shared recordings.
typedef AruSessionDiscarder = Future<void> Function(String sessionId);

/// Starts audio capture for a scheduled ARU cycle.
typedef AruCycleRecordingStarter =
    Future<String?> Function(LiveSession session, AruCycleWindow window);

/// Stops audio capture for the active ARU cycle.
typedef AruCycleRecordingStopper =
    Future<String?> Function(
      LiveSession session,
      AruCycleMetadata cycle,
      DateTime endedAt,
    );

/// Saves a detection-only clip while an ARU cycle is recording.
typedef AruDetectionClipSaver =
    Future<String?> Function(LiveSession session, DetectionRecord record);

/// Minimal ARU controller that owns schedule transitions and session metadata.
///
/// Audio capture, inference, notifications, and platform recovery can be wired
/// onto this state machine later. This class intentionally has no Flutter or
/// platform dependencies, making the scheduling behavior unit-testable.
class AruController {
  AruController({
    required AruSessionSaver saveSession,
    AruSessionDiscarder? discardSession,
    AruCycleRecordingStarter? startCycleRecording,
    AruCycleRecordingStopper? stopCycleRecording,
    AruDetectionClipSaver? saveDetectionClip,
    DateTime Function()? now,
  }) : _saveSession = saveSession,
       _discardSession = discardSession,
       _startCycleRecording = startCycleRecording,
       _stopCycleRecording = stopCycleRecording,
       _saveDetectionClip = saveDetectionClip,
       _now = now ?? DateTime.now;

  final AruSessionSaver _saveSession;
  final AruSessionDiscarder? _discardSession;
  final AruCycleRecordingStarter? _startCycleRecording;
  final AruCycleRecordingStopper? _stopCycleRecording;
  final AruDetectionClipSaver? _saveDetectionClip;
  final DateTime Function() _now;

  AruControllerState _state = AruControllerState.idle;
  LiveSession? _session;
  AruScheduleCalculator? _calculator;
  String? _errorMessage;
  int? _activeCycleIndex;
  DateTime? _activeCycleStart;
  AruDetectionSampler? _sampler;
  LiveSession? _lastReviewSession;

  AruControllerState get state => _state;
  LiveSession? get session => _session;
  String? get errorMessage => _errorMessage;
  LiveSession? get reviewSession => _lastReviewSession ?? _session;

  Future<void> restoreDeployment(LiveSession session, {DateTime? now}) async {
    if (session.type != SessionType.aru || session.aruMetadata == null) {
      throw ArgumentError('Session is not an ARU deployment');
    }
    if (session.endTime != null) {
      throw ArgumentError('ARU deployment is already completed');
    }
    if (_state != AruControllerState.idle &&
        _state != AruControllerState.completed &&
        _state != AruControllerState.error) {
      throw StateError('ARU deployment already started');
    }

    _state = AruControllerState.recovering;
    _errorMessage = null;
    _session = session;
    _calculator = AruScheduleCalculator(
      session.aruMetadata!.toScheduleConfig(),
    );
    _activeCycleIndex = null;
    _activeCycleStart = null;
    _lastReviewSession = session;
    _sampler = AruDetectionSampler(
      mode: samplingModeFromString(session.aruMetadata!.samplingMode),
      topN: session.aruMetadata!.topNPerSpecies,
      scopeKeyFor: _samplingScopeKeyFor,
      timeBucketFor: _samplingTimeBucketFor,
    );

    _normalizeRecoveredCycles(now ?? _now());
    await evaluate(now: now ?? _now());
  }

  Future<void> startDeployment({
    required String sessionId,
    required SessionSettings settings,
    required AruDeploymentMetadata metadata,
    String? observerName,
    double? latitude,
    double? longitude,
    int? sessionNumber,
  }) async {
    if (_state != AruControllerState.idle &&
        _state != AruControllerState.completed &&
        _state != AruControllerState.error) {
      throw StateError('ARU deployment already started');
    }

    _state = AruControllerState.preparing;
    _errorMessage = null;
    _activeCycleIndex = null;
    _activeCycleStart = null;

    try {
      _calculator = AruScheduleCalculator(metadata.toScheduleConfig());
      _session = LiveSession(
        id: sessionId,
        type: SessionType.aru,
        startTime: metadata.scheduleStart,
        customName: _deploymentSessionName(metadata),
        settings: settings,
        observerName: observerName,
        latitude: latitude,
        longitude: longitude,
        aruMetadata: metadata,
        sessionNumber: sessionNumber,
      );
      _lastReviewSession = _session;
      _sampler = AruDetectionSampler(
        mode: samplingModeFromString(metadata.samplingMode),
        topN: metadata.topNPerSpecies,
        scopeKeyFor: _samplingScopeKeyFor,
        timeBucketFor: _samplingTimeBucketFor,
      );
      await _persist();
      await evaluate(now: _now());
    } catch (e) {
      _state = AruControllerState.error;
      _errorMessage = e.toString();
      rethrow;
    }
  }

  /// Re-evaluate the schedule and transition between waiting/recording states.
  Future<void> evaluate({DateTime? now}) async {
    if (_state == AruControllerState.completed ||
        _state == AruControllerState.stopping) {
      return;
    }

    final session = _requireSession();
    final calculator = _calculator;
    if (calculator == null) {
      throw StateError('ARU schedule is not initialized');
    }

    final evalTime = now ?? _now();
    final snapshot = calculator.snapshotAt(evalTime);
    switch (snapshot.status) {
      case AruScheduleStatus.notStarted:
      case AruScheduleStatus.waiting:
        await _leaveActiveCycle(
          status: AruCycleStatus.completed,
          endedAt: evalTime,
        );
        _state = AruControllerState.waiting;
        break;
      case AruScheduleStatus.recording:
        await _enterCycle(snapshot.currentWindow!);
        _state = AruControllerState.recording;
        break;
      case AruScheduleStatus.completed:
        await _leaveActiveCycle(
          status: AruCycleStatus.completed,
          endedAt: evalTime,
        );
        session.endTime = evalTime;
        _state = AruControllerState.completed;
        break;
    }

    await _persist();
  }

  Future<void> syncDetections(List<DetectionRecord> records) async {
    final session = _session;
    if (session == null || records.isEmpty) return;

    var changed = false;
    for (final record in records) {
      final existingIndex = _detectionIndex(session.detections, record);
      final existing =
          existingIndex == -1 ? null : session.detections[existingIndex];
      final synced = await _syncedDetectionRecord(session, record, existing);

      if (existingIndex == -1) {
        session.addDetection(synced);
        changed = true;
      } else if (!_sameDetectionPayload(existing!, synced)) {
        session.detections[existingIndex] = synced;
        _sampler?.replaceRecord(existing, synced);
        changed = true;
      }
    }
    if (!changed) return;

    _updateCycleDetectionStats(session);
    await _persist();
  }

  Future<DetectionRecord> _syncedDetectionRecord(
    LiveSession session,
    DetectionRecord record,
    DetectionRecord? existing,
  ) async {
    var audioClipPath = existing?.audioClipPath ?? record.audioClipPath;
    final closesNow =
        record.endTimestamp != null && existing?.endTimestamp == null;
    final mode = recordingModeFromString(
      session.aruMetadata?.recordingMode ?? RecordingMode.off.name,
    );

    if (closesNow &&
        mode == RecordingMode.detectionsOnly &&
        audioClipPath == null) {
      audioClipPath = await _saveDetectionClip?.call(session, record);
    }

    final synced = DetectionRecord(
      scientificName: record.scientificName,
      commonName: record.commonName,
      confidence:
          existing != null && existing.confidence > record.confidence
              ? existing.confidence
              : record.confidence,
      timestamp: record.timestamp,
      endTimestamp: record.endTimestamp ?? existing?.endTimestamp,
      audioClipPath: audioClipPath,
      source: record.source,
      latitude: record.latitude ?? existing?.latitude,
      longitude: record.longitude ?? existing?.longitude,
      confirmedAt: existing?.confirmedAt ?? record.confirmedAt,
      note: existing?.note ?? record.note,
      voiceMemoPath: existing?.voiceMemoPath ?? record.voiceMemoPath,
    );

    if (closesNow) {
      await _sampler?.onRecordClosed(synced);
    }

    return synced;
  }

  int _detectionIndex(List<DetectionRecord> records, DetectionRecord target) {
    return records.indexWhere(
      (record) =>
          record.scientificName == target.scientificName &&
          record.timestamp == target.timestamp,
    );
  }

  bool _sameDetectionPayload(DetectionRecord a, DetectionRecord b) {
    return a.scientificName == b.scientificName &&
        a.commonName == b.commonName &&
        a.confidence == b.confidence &&
        a.timestamp == b.timestamp &&
        a.endTimestamp == b.endTimestamp &&
        a.audioClipPath == b.audioClipPath &&
        a.latitude == b.latitude &&
        a.longitude == b.longitude &&
        a.confirmedAt == b.confirmedAt &&
        a.note == b.note &&
        a.voiceMemoPath == b.voiceMemoPath;
  }

  void _updateCycleDetectionStats(LiveSession session) {
    final cycles = session.aruMetadata?.cycles;
    if (cycles == null) return;
    final tracksClips =
        recordingModeFromString(
          session.aruMetadata?.recordingMode ?? RecordingMode.off.name,
        ) ==
        RecordingMode.detectionsOnly;

    for (final cycle in cycles) {
      final detections = _detectionsInWindow(
        session,
        cycle.plannedStart,
        cycle.plannedEnd,
      );
      final retainedClipCount =
          detections
              .where((detection) => detection.audioClipPath != null)
              .length;
      _upsertCycle(
        AruCycleMetadata(
          index: cycle.index,
          plannedStart: cycle.plannedStart,
          plannedEnd: cycle.plannedEnd,
          actualStart: cycle.actualStart,
          actualEnd: cycle.actualEnd,
          status: cycle.status,
          recordingPath: cycle.recordingPath,
          detectionCount: detections.length,
          retainedClipCount: retainedClipCount,
          droppedClipCount:
              tracksClips
                  ? (detections.length - retainedClipCount).clamp(
                    0,
                    detections.length,
                  )
                  : cycle.droppedClipCount,
          note: cycle.note,
        ),
      );
    }
  }

  List<DetectionRecord> _detectionsInWindow(
    LiveSession session,
    DateTime start,
    DateTime end,
  ) {
    return session.detections.where((detection) {
      return !detection.timestamp.isBefore(start) &&
          detection.timestamp.isBefore(end);
    }).toList();
  }

  /// Stop the deployment manually or because a guard fired.
  Future<LiveSession> stop({
    SessionStopReason reason = SessionStopReason.manual,
    num? reasonValue,
    DateTime? now,
  }) async {
    final session = _requireSession();
    final stopTime = now ?? _now();

    _state = AruControllerState.stopping;
    await _leaveActiveCycle(status: AruCycleStatus.stopped, endedAt: stopTime);
    session.stopReason = reason;
    session.stopReasonValue = reasonValue;
    session.endTime = stopTime;
    _state = AruControllerState.completed;
    await _persist();
    return session;
  }

  LiveSession _requireSession() {
    final session = _session;
    if (session == null) throw StateError('No ARU deployment is active');
    return session;
  }

  Future<void> _enterCycle(AruCycleWindow window) async {
    final session = _requireSession();
    if (_activeCycleIndex == window.index) return;

    await _leaveActiveCycle(
      status: AruCycleStatus.completed,
      endedAt: window.start,
    );

    _activeCycleIndex = window.index;
    _activeCycleStart = window.start;
    session.segments.add(SessionSegment(startTime: window.start));
    final recordingPath =
        session.aruMetadata?.recordingMode == 'off'
            ? null
            : await _startCycleRecording?.call(session, window);
    _upsertCycle(
      AruCycleMetadata(
        index: window.index,
        plannedStart: window.start,
        plannedEnd: window.plannedEnd,
        actualStart: window.start,
        status: AruCycleStatus.recording,
        recordingPath: recordingPath,
      ),
    );
  }

  Future<void> _leaveActiveCycle({
    required AruCycleStatus status,
    required DateTime endedAt,
  }) async {
    final session = _session;
    final index = _activeCycleIndex;
    final startedAt = _activeCycleStart;
    if (session == null || index == null || startedAt == null) return;

    final existing = _cycleAt(index);
    final effectiveEnd =
        status == AruCycleStatus.completed &&
                existing != null &&
                endedAt.isAfter(existing.plannedEnd)
            ? existing.plannedEnd
            : endedAt;

    if (session.segments.isNotEmpty) {
      final last = session.segments.last;
      last.endTime ??= effectiveEnd;
    }
    session.accumulateRecordedSeconds(
      effectiveEnd.difference(startedAt).inSeconds,
    );

    final stoppedPath = await _stopCycleRecording?.call(
      session,
      existing ??
          AruCycleMetadata(
            index: index,
            plannedStart: startedAt,
            plannedEnd: effectiveEnd,
            actualStart: startedAt,
            status: status,
          ),
      effectiveEnd,
    );

    final finalizedCycle = AruCycleMetadata(
      index: index,
      plannedStart: existing?.plannedStart ?? startedAt,
      plannedEnd: existing?.plannedEnd ?? effectiveEnd,
      actualStart: existing?.actualStart ?? startedAt,
      actualEnd: effectiveEnd,
      status: status,
      recordingPath: stoppedPath ?? existing?.recordingPath,
      detectionCount: existing?.detectionCount ?? 0,
      retainedClipCount: existing?.retainedClipCount ?? 0,
      droppedClipCount: existing?.droppedClipCount ?? 0,
      note: existing?.note,
    );
    _upsertCycle(finalizedCycle);

    final eachCycleIsSession = session.aruMetadata?.eachCycleIsSession ?? false;
    if (stoppedPath != null && !eachCycleIsSession) {
      session.recordingPath = stoppedPath;
    }

    if (eachCycleIsSession) {
      final cycleDetections = _detectionsInWindow(
        session,
        startedAt,
        effectiveEnd,
      );

      final cycleSession = LiveSession(
        id: '${session.id}_cycle_$index',
        type: SessionType.aru,
        sessionNumber: session.sessionNumber,
        startTime: startedAt,
        endTime: effectiveEnd,
        customName: _cycleSessionName(session, index),
        settings: session.settings,
        observerName: session.observerName,
        latitude: session.latitude,
        longitude: session.longitude,
        recordingPath: stoppedPath ?? existing?.recordingPath,
        detections: cycleDetections,
        aruMetadata: _cycleDeploymentMetadata(
          session,
          finalizedCycle,
          cycleDetections.length,
        ),
      );

      await _saveSession(cycleSession);
      _lastReviewSession = cycleSession;
    } else {
      _lastReviewSession = session;
    }

    _activeCycleIndex = null;
    _activeCycleStart = null;
  }

  AruCycleMetadata? _cycleAt(int index) {
    final cycles = _session?.aruMetadata?.cycles;
    if (cycles == null) return null;
    for (final cycle in cycles) {
      if (cycle.index == index) return cycle;
    }
    return null;
  }

  AruCycleMetadata? _cycleFor(DetectionRecord record) {
    final cycles = _session?.aruMetadata?.cycles;
    if (cycles == null) return null;
    for (final cycle in cycles) {
      if (!record.timestamp.isBefore(cycle.plannedStart) &&
          record.timestamp.isBefore(cycle.plannedEnd)) {
        return cycle;
      }
    }
    return null;
  }

  String _samplingScopeKeyFor(DetectionRecord record) {
    final metadata = _session?.aruMetadata;
    final sessionId = _session?.id ?? 'active';
    if (metadata?.eachCycleIsSession == true) {
      return 'session:${sessionId}_cycle_${_cycleFor(record)?.index ?? _activeCycleIndex ?? 0}';
    }
    return 'session:$sessionId';
  }

  int _samplingTimeBucketFor(DetectionRecord record) {
    final metadata = _session?.aruMetadata;
    final cycle = _cycleFor(record);
    if (metadata?.eachCycleIsSession == true) {
      final base = cycle?.plannedStart ?? _activeCycleStart ?? record.timestamp;
      return record.timestamp.difference(base).inMinutes;
    }
    if (cycle != null) return cycle.index;

    final base = metadata?.scheduleStart ?? record.timestamp;
    return record.timestamp.difference(base).inHours;
  }

  bool _shouldDiscardAggregateSession(LiveSession session) {
    final metadata = session.aruMetadata;
    if (metadata == null) return false;
    return metadata.eachCycleIsSession &&
        recordingModeFromString(metadata.recordingMode) ==
            RecordingMode.detectionsOnly;
  }

  Future<void> _discardAggregateSession(LiveSession session) async {
    final discard = _discardSession;
    if (discard == null || !_shouldDiscardAggregateSession(session)) return;
    await discard(session.id);
  }

  void _upsertCycle(AruCycleMetadata cycle) {
    final cycles = _session?.aruMetadata?.cycles;
    if (cycles == null) return;
    final existingIndex = cycles.indexWhere((c) => c.index == cycle.index);
    if (existingIndex >= 0) {
      cycles[existingIndex] = cycle;
    } else {
      cycles.add(cycle);
      cycles.sort((a, b) => a.index.compareTo(b.index));
    }
  }

  void _normalizeRecoveredCycles(DateTime now) {
    final cycles = _session?.aruMetadata?.cycles;
    if (cycles == null) return;

    for (final cycle in cycles.toList()) {
      if (cycle.status != AruCycleStatus.recording) continue;
      final end = now.isAfter(cycle.plannedEnd) ? cycle.plannedEnd : now;
      _upsertCycle(
        AruCycleMetadata(
          index: cycle.index,
          plannedStart: cycle.plannedStart,
          plannedEnd: cycle.plannedEnd,
          actualStart: cycle.actualStart,
          actualEnd: end,
          status: AruCycleStatus.partial,
          recordingPath: cycle.recordingPath,
          detectionCount: cycle.detectionCount,
          retainedClipCount: cycle.retainedClipCount,
          droppedClipCount: cycle.droppedClipCount,
          note: cycle.note,
        ),
      );
    }
  }

  Future<void> _persist() async {
    final session = _session;
    if (session == null) return;
    if (_shouldDiscardAggregateSession(session)) {
      if (_state == AruControllerState.completed) {
        await _discardAggregateSession(session);
      }
      return;
    }
    await _saveSession(session);
  }

  AruDeploymentMetadata? _cycleDeploymentMetadata(
    LiveSession session,
    AruCycleMetadata cycle,
    int detectionCount,
  ) {
    final metadata = session.aruMetadata;
    if (metadata == null) return null;
    return AruDeploymentMetadata(
      deploymentName: metadata.deploymentName,
      stationId: metadata.stationId,
      scheduleStart: cycle.plannedStart,
      cycleDurationSeconds:
          cycle.plannedEnd.difference(cycle.plannedStart).inSeconds,
      repeatIntervalSeconds: metadata.repeatIntervalSeconds,
      scheduleEnd: cycle.actualEnd,
      maxCycles: 1,
      lowBatteryStopPercent: metadata.lowBatteryStopPercent,
      dielPattern: metadata.dielPattern,
      latitude: metadata.latitude,
      longitude: metadata.longitude,
      recordingMode: metadata.recordingMode,
      recordingFormat: metadata.recordingFormat,
      samplingMode: metadata.samplingMode,
      topNPerSpecies: metadata.topNPerSpecies,
      testCycleEnabled: _isTestCycle(session, cycle.index),
      eachCycleIsSession: true,
      cycles: [
        AruCycleMetadata(
          index: cycle.index,
          plannedStart: cycle.plannedStart,
          plannedEnd: cycle.plannedEnd,
          actualStart: cycle.actualStart,
          actualEnd: cycle.actualEnd,
          status: cycle.status,
          recordingPath: cycle.recordingPath,
          detectionCount: detectionCount,
          retainedClipCount: cycle.retainedClipCount,
          droppedClipCount: cycle.droppedClipCount,
          note: cycle.note,
        ),
      ],
    );
  }

  String _cycleSessionName(LiveSession session, int cycleIndex) {
    final isTestRun = _isTestCycle(session, cycleIndex);
    final cyclePart =
        isTestRun
            ? 'Test Run'
            : 'Cycle ${_displayCycleNumber(session, cycleIndex)}';
    final name = session.customName?.trim();
    if (name != null && name.isNotEmpty) {
      return '$name - $cyclePart';
    }

    final deploymentNumber = session.sessionNumber;
    final deploymentPart =
        deploymentNumber != null
            ? 'Deployment #$deploymentNumber'
            : 'Deployment';
    return 'ARU $deploymentPart - $cyclePart';
  }

  static String? _deploymentSessionName(AruDeploymentMetadata metadata) {
    final deploymentName = metadata.deploymentName?.trim();
    final stationId = metadata.stationId?.trim();
    final hasDeployment = deploymentName != null && deploymentName.isNotEmpty;
    final hasStation = stationId != null && stationId.isNotEmpty;
    if (hasDeployment && hasStation) return '$deploymentName - $stationId';
    if (hasDeployment) return deploymentName;
    if (hasStation) return stationId;
    return null;
  }

  int _displayCycleNumber(LiveSession session, int cycleIndex) {
    if (session.aruMetadata?.testCycleEnabled == true) {
      return cycleIndex;
    }
    return cycleIndex + 1;
  }

  bool _isTestCycle(LiveSession session, int cycleIndex) {
    return session.aruMetadata?.testCycleEnabled == true && cycleIndex == 0;
  }
}
