// =============================================================================
// ARU Runner - Provider-scoped driver for autonomous recording deployments
// =============================================================================
//
// Owns the periodic drive loop that advances an ARU deployment: re-evaluating
// the schedule, starting/stopping inference, auto-stopping on low battery,
// syncing detections, and updating the foreground notification.
//
// Unlike the previous design (where this loop lived inside the active screen
// and was cancelled in `deactivate`), the runner is held by a long-lived
// provider so the deployment keeps progressing while the screen is
// backgrounded or covered by another route — mirroring how [SurveyController]
// drives Survey Mode independently of its screen. Background progress relies on
// the ARU foreground service's partial wakelock (`allowWakeLock: true`), which
// keeps the CPU — and therefore this timer — running while the screen is off,
// without forcing the screen to stay on during a long unattended deployment.
// =============================================================================

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/locale_time_format.dart';
import '../explore/explore_providers.dart';
import '../live/live_controller.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import '../recording/recording_service.dart';
import 'aru_controller.dart';
import 'aru_notification.dart';
import 'aru_providers.dart';
import 'aru_schedule.dart';

/// Outcome handed to the UI when a deployment finishes (completion, manual
/// stop, or auto-stop). [reviewSession] is the session to open in review,
/// when one exists.
class AruFinishResult {
  const AruFinishResult({
    required this.reviewSession,
    required this.reason,
    this.batteryLevel,
  });

  final LiveSession? reviewSession;
  final SessionStopReason reason;
  final int? batteryLevel;
}

/// Drives an active ARU deployment independently of the active screen.
///
/// The runner is created once via [aruRunnerProvider] and kept alive for the
/// app's lifetime, so the deployment loop survives screen disposal and
/// backgrounding (kept alive on Android by the ARU foreground service).
class AruRunner {
  AruRunner(this._ref);

  final Ref _ref;
  final Battery _battery = Battery();
  final AruNotificationService _notificationService = AruNotificationService();

  Timer? _timer;
  bool _running = false;
  bool _tickBusy = false;
  bool _stopping = false;
  bool _finishing = false;
  bool _disposed = false;
  bool _inferenceStarting = false;
  bool _aruInferenceActive = false;
  DateTime? _lastBatteryCheck;
  Future<void> _syncDetectionsTail = Future<void>.value();

  AppLocalizations? _l10n;
  bool _use24Hour = false;

  /// Invoked when the deployment finishes so the UI can open review and show
  /// a status message. Optional — when no screen is attached the deployment
  /// is still finalized and persisted.
  void Function(AruFinishResult result)? onFinished;

  /// Whether the drive loop is currently running.
  bool get isRunning => _running;

  /// Latest localization context, refreshed by the screen so background
  /// notification text stays localized.
  void refreshLocalization(
    AppLocalizations l10n, {
    required bool use24Hour,
  }) {
    _l10n = l10n;
    _use24Hour = use24Hour;
  }

  /// Start (or re-confirm) the drive loop. Idempotent: safe to call from every
  /// entry point that activates a deployment (fresh start, restore, notification
  /// relaunch). The caller must have already started/restored the
  /// [AruController] and published its state to [aruStateProvider]/
  /// [aruSessionProvider].
  void attach(
    AppLocalizations l10n, {
    required bool use24Hour,
  }) {
    if (_disposed) return;
    _l10n = l10n;
    _use24Hour = use24Hour;

    final liveController = _ref.read(liveControllerProvider);
    liveController.onStateChanged = _onInferenceStateChanged;

    if (_running) return;
    // Reset transient flags so a fresh deployment is not blocked by state left
    // over from a previously finished one (the runner is long-lived).
    _stopping = false;
    _finishing = false;
    _tickBusy = false;
    _aruInferenceActive = false;
    _lastBatteryCheck = null;
    _running = true;
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    unawaited(_kickoff());
  }

  Future<void> _kickoff() async {
    await _tick();
    if (!_running) return;
    await _syncNotification();
  }

  /// Request a manual stop of the active deployment.
  Future<void> requestStop() async {
    if (_stopping || _finishing) return;
    _stopping = true;
    final result = await _finishDeployment(reason: SessionStopReason.manual);
    _stopping = false;
    _notifyFinished(result);
  }

  Future<void> _tick() async {
    if (!_running || _stopping || _finishing || _tickBusy) return;
    _tickBusy = true;
    try {
      final controller = _ref.read(aruControllerProvider);
      final session = controller.session;
      if (session == null ||
          controller.state == AruControllerState.completed) {
        return;
      }
      if (controller.state == AruControllerState.recording &&
          _scheduleSnapshot(session)?.currentWindow == null) {
        await _stopInference();
      }
      if (await _stopIfBatteryBelowThreshold(controller)) {
        return;
      }
      await controller.evaluate();
      if (!_running) return;
      _publishState(controller);
      if (controller.state == AruControllerState.completed) {
        _stopping = true;
        final result = await _finishDeployment(
          reason: SessionStopReason.maxDuration,
        );
        _stopping = false;
        _notifyFinished(result);
        return;
      }
      await _syncInferenceSession(controller.state, controller.session);
      await _syncNotification();
    } finally {
      _tickBusy = false;
    }
  }

  void _publishState(AruController controller) {
    _ref.read(aruStateProvider.notifier).state = controller.state;
    _ref.read(aruSessionProvider.notifier).state = controller.session;
  }

  // ── Inference orchestration ───────────────────────────────────────────────

  void _onInferenceStateChanged() {
    if (!_running || _finishing) return;
    unawaited(_syncDetectionsFromInference());
  }

  Future<void> _syncDetectionsFromInference() async {
    final liveController = _ref.read(liveControllerProvider);
    await _syncDetections(liveController.sessionDetections);
  }

  Future<void> _syncDetections(List<DetectionRecord> detections) async {
    final snapshot = List<DetectionRecord>.of(detections);
    final previous = _syncDetectionsTail.catchError((_) {});
    final next = previous.then((_) => _syncDetectionsNow(snapshot));
    _syncDetectionsTail = next.catchError((_) {});
    await next;
  }

  Future<void> _syncDetectionsNow(List<DetectionRecord> detections) async {
    final controller = _ref.read(aruControllerProvider);
    await controller.syncDetections(detections);
    if (!_running) return;
    _ref.read(aruSessionProvider.notifier).state = controller.session;
  }

  Future<void> _syncInferenceSession(
    AruControllerState state,
    LiveSession? session,
  ) async {
    if (session == null) return;
    if (state == AruControllerState.recording) {
      await _startInference(session);
    } else {
      await _stopInference();
    }
  }

  Future<void> _startInference(LiveSession session) async {
    if (_aruInferenceActive || _inferenceStarting) return;
    _inferenceStarting = true;
    try {
      final controller = _ref.read(liveControllerProvider);
      if (controller.state == LiveState.idle) {
        await controller.loadModel();
      }
      if (controller.state != LiveState.ready) return;
      if (!_running) return;

      final geoScores = await _ref.read(geoScoresProvider.future);
      final geoThreshold = _ref.read(geoThresholdProvider);
      final geoModelSpeciesNames = await _ref.read(
        geoModelSpeciesNamesProvider.future,
      );
      if (!_running) return;

      await controller.startSession(
        windowDuration: session.settings.windowDuration,
        inferenceRate: session.settings.inferenceRate,
        confidenceThreshold: session.settings.confidenceThreshold,
        speciesFilterMode: session.settings.speciesFilterMode,
        recordingMode: RecordingMode.off,
        geoScores: geoScores,
        geoThreshold: geoThreshold,
        geoModelSpeciesNames: geoModelSpeciesNames,
        poolingWindows: session.settings.poolingWindows,
        poolingMode: session.settings.poolingMode ?? 'lme',
        sensitivity: session.settings.sensitivity ?? 1.0,
        gainLinear: session.settings.gainLinear,
        highPassHz: session.settings.highPassHz,
        latitude: session.latitude,
        longitude: session.longitude,
        clearRingBuffer: false,
      );
      _aruInferenceActive = controller.state == LiveState.active;
      _onInferenceStateChanged();
    } finally {
      _inferenceStarting = false;
    }
  }

  Future<void> _stopInference() async {
    final controller = _ref.read(liveControllerProvider);
    if (controller.session == null &&
        controller.state != LiveState.active &&
        controller.state != LiveState.paused) {
      _aruInferenceActive = false;
      return;
    }

    await _syncDetectionsFromInference();
    final completedSession = await controller.finalizeSession();
    if (completedSession != null) {
      await _syncDetections(completedSession.detections);
    }
    _aruInferenceActive = false;
  }

  // ── Battery auto-stop ─────────────────────────────────────────────────────

  Future<bool> _stopIfBatteryBelowThreshold(AruController controller) async {
    final threshold = controller.session?.aruMetadata?.lowBatteryStopPercent;
    if (threshold == null || threshold <= 0) return false;

    final now = DateTime.now();
    if (_lastBatteryCheck != null &&
        now.difference(_lastBatteryCheck!) < const Duration(minutes: 1)) {
      return false;
    }
    _lastBatteryCheck = now;

    try {
      final level = await _battery.batteryLevel;
      if (level > threshold) return false;

      _stopping = true;
      final result = await _finishDeployment(
        reason: SessionStopReason.lowBattery,
        reasonValue: level,
      );
      _stopping = false;
      _notifyFinished(
        AruFinishResult(
          reviewSession: result.reviewSession,
          reason: SessionStopReason.lowBattery,
          batteryLevel: level,
        ),
      );
      return true;
    } catch (error) {
      debugPrint('[AruRunner] battery check failed: $error');
      return false;
    }
  }

  // ── Notification ──────────────────────────────────────────────────────────

  Future<void> _syncNotification() async {
    final session = _ref.read(aruSessionProvider);
    final state = _ref.read(aruStateProvider);
    if (session == null || state == AruControllerState.completed) {
      await _notificationService.stop();
      return;
    }

    final l10n = _l10n;
    if (l10n == null) return;
    final text = _notificationText(l10n, state, session);
    if (_notificationService.isRunning) {
      await _notificationService.update(
        title: l10n.aruNotificationTitle,
        text: text,
      );
    } else {
      await _notificationService.start(
        title: l10n.aruNotificationTitle,
        text: text,
      );
    }
  }

  String _notificationText(
    AppLocalizations l10n,
    AruControllerState state,
    LiveSession session,
  ) {
    final status = switch (state) {
      AruControllerState.recording => l10n.aruActiveRecording,
      AruControllerState.completed => l10n.aruActiveCompleted,
      _ => l10n.aruActiveWaiting,
    };
    final snapshot = _scheduleSnapshot(session);
    final current = snapshot?.currentWindow;
    final next = snapshot?.nextWindow;
    if (current != null) {
      final label =
          '${formatLocaleTime(current.start, l10n.localeName, alwaysUse24HourFormat: _use24Hour)} - '
          '${formatLocaleTime(current.end, l10n.localeName, alwaysUse24HourFormat: _use24Hour)}';
      return '$status - $label';
    }
    if (next != null) {
      return '$status - ${formatLocaleTime(next.start, l10n.localeName, alwaysUse24HourFormat: _use24Hour)}';
    }
    return '$status - ${l10n.aruCompletedCycles}: ${_completedCycleCount(session)}';
  }

  // ── Finish / teardown ─────────────────────────────────────────────────────

  Future<AruFinishResult> _finishDeployment({
    required SessionStopReason reason,
    num? reasonValue,
  }) async {
    _finishing = true;
    final controller = _ref.read(aruControllerProvider);
    try {
      // Finalize inference while capture is still running, then let the
      // controller close the active cycle. Audio capture is owned solely by the
      // cycle hooks (startCycleRecording / stopCycleRecording); controller.stop
      // routes through _leaveActiveCycle -> stopCycleRecording, which releases
      // capture. The runner must not stop capture independently or the two
      // owners can race (double stop / stop-before-start).
      await _stopInference();
      await _syncDetectionsTail;
      await controller.stop(reason: reason, reasonValue: reasonValue);
      _publishState(controller);
      await _notificationService.stop();
      _ref.invalidate(sessionListProvider);
      return AruFinishResult(
        reviewSession: controller.reviewSession,
        reason: reason,
      );
    } finally {
      _stopLoop();
      if (controller.state != AruControllerState.completed) {
        _finishing = false;
      }
    }
  }

  void _notifyFinished(AruFinishResult result) {
    onFinished?.call(result);
  }

  void _stopLoop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    final liveController = _ref.read(liveControllerProvider);
    if (liveController.onStateChanged == _onInferenceStateChanged) {
      liveController.onStateChanged = null;
    }
  }

  void dispose() {
    _disposed = true;
    onFinished = null;
    _stopLoop();
  }
}

// ── Shared pure helpers ──────────────────────────────────────────────────────

AruScheduleSnapshot? _scheduleSnapshot(LiveSession session) {
  final metadata = session.aruMetadata;
  if (metadata == null) return null;
  return AruScheduleCalculator(
    metadata.toScheduleConfig(),
  ).snapshotAt(DateTime.now());
}

int _completedCycleCount(LiveSession session) {
  return (session.aruMetadata?.cycles ?? const <AruCycleMetadata>[])
      .where(
        (cycle) =>
            cycle.status == AruCycleStatus.completed ||
            cycle.status == AruCycleStatus.stopped ||
            cycle.status == AruCycleStatus.partial,
      )
      .length;
}
