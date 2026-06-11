// =============================================================================
// ARU Providers - Riverpod wiring for autonomous recording deployments
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/settings_providers.dart';
import '../audio/audio_capture_service.dart';
import '../audio/audio_providers.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import '../recording/recording_service.dart';
import 'aru_controller.dart';
import 'aru_storage_estimator.dart';

/// Pure storage estimator used by ARU setup readiness checks.
final aruStorageEstimatorProvider = Provider<AruStorageEstimator>((ref) {
  return const AruStorageEstimator();
});

/// Recording service used by ARU cycle recordings.
final aruRecordingServiceProvider = Provider<RecordingService>((ref) {
  final ringBuffer = ref.watch(ringBufferProvider);
  final clipContext = ref.watch(clipContextProvider);
  final windowSeconds = ref.watch(windowDurationProvider);
  final service = RecordingService(
    ringBuffer: ringBuffer,
    sampleRate: AppConstants.sampleRate,
    clipContextSeconds: clipContext,
    windowSeconds: windowSeconds,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// ARU controller skeleton.
///
/// The controller owns schedule/session transitions and delegates concrete
/// cycle recording to injected services so the state machine remains testable.
final aruControllerProvider = Provider<AruController>((ref) {
  final repository = ref.watch(sessionRepositoryProvider);
  final recordingService = ref.watch(aruRecordingServiceProvider);
  final capture = ref.watch(audioCaptureServiceProvider);
  final captureState = ref.watch(captureStateProvider.notifier);
  var aruCaptureActive = false;

  return AruController(
    saveSession: repository.save,
    startCycleRecording: (session, window) async {
      final metadata = session.aruMetadata;
      final mode = recordingModeFromString(metadata?.recordingMode ?? 'off');
      if (mode == RecordingMode.off) return null;

      capture.setGain(session.settings.gainLinear ?? 1.0);
      capture.setHighPassCutoff(session.settings.highPassHz ?? 0.0);

      final path = await recordingService.startRecording(
        sessionId:
            '${session.id}/cycle_${window.index.toString().padLeft(3, '0')}',
        mode: mode,
        format: metadata?.recordingFormat ?? ref.read(recordingFormatProvider),
      );
      if (capture.state != CaptureState.capturing) {
        await captureState.start(deviceId: ref.read(selectedDeviceProvider));
        aruCaptureActive = true;
      }
      return path;
    },
    saveDetectionClip: (session, record) async {
      final timestamp = record.timestamp.toUtc().millisecondsSinceEpoch;
      final safeName = record.scientificName.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]+'),
        '_',
      );
      return recordingService.saveDetectionClip(
        clipName: 'clip_${timestamp}_$safeName',
      );
    },
    stopCycleRecording: (session, cycle, endedAt) async {
      if (aruCaptureActive) {
        await captureState.stop();
        aruCaptureActive = false;
      }
      return recordingService.stopRecording();
    },
  );
});

/// Reactive ARU lifecycle state.
final aruStateProvider = StateProvider<AruControllerState>(
  (ref) => AruControllerState.idle,
);

/// Currently active ARU session, if any.
final aruSessionProvider = StateProvider<LiveSession?>((ref) => null);
