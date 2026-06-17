// =============================================================================
// ARU Providers - Riverpod wiring for autonomous recording deployments
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/settings_providers.dart';
import '../audio/audio_capture_service.dart';
import '../audio/audio_providers.dart';
import '../audio/ring_buffer.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import '../recording/recording_service.dart';
import 'aru_controller.dart';
import 'aru_storage_estimator.dart';

typedef AruCycleRecordingStart =
    Future<String?> Function({
      required String sessionId,
      required RecordingMode mode,
      required String format,
    });

@visibleForTesting
Future<String?> startAruCycleAudio({
  required RingBuffer ringBuffer,
  required CaptureState captureState,
  required Future<void> Function() startCapture,
  required void Function(double value) setGain,
  required void Function(double value) setHighPassCutoff,
  required AruCycleRecordingStart startRecording,
  required RecordingMode recordingMode,
  required String recordingSessionId,
  required String recordingFormat,
  required double gainLinear,
  required double highPassHz,
}) async {
  setGain(gainLinear);
  setHighPassCutoff(highPassHz);
  ringBuffer.clear();

  String? path;
  if (recordingMode != RecordingMode.off) {
    path = await startRecording(
      sessionId: recordingSessionId,
      mode: recordingMode,
      format: recordingFormat,
    );
  }
  if (captureState != CaptureState.capturing) {
    await startCapture();
  }
  return path;
}

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
  final ringBuffer = ref.watch(ringBufferProvider);
  final capture = ref.watch(audioCaptureServiceProvider);
  final captureState = ref.watch(captureStateProvider.notifier);
  var aruCaptureActive = false;

  return AruController(
    saveSession: repository.save,
    discardSession: repository.deleteMetadataOnly,
    startCycleRecording: (session, window) async {
      final metadata = session.aruMetadata;
      final mode = recordingModeFromString(metadata?.recordingMode ?? 'off');
      final captureWasRunning = capture.state == CaptureState.capturing;
      final path = await startAruCycleAudio(
        ringBuffer: ringBuffer,
        captureState: capture.state,
        startCapture: () async {
          await captureState.start(deviceId: ref.read(selectedDeviceProvider));
        },
        setGain: capture.setGain,
        setHighPassCutoff: capture.setHighPassCutoff,
        startRecording: recordingService.startRecording,
        recordingMode: mode,
        recordingSessionId:
            '${session.id}/cycle_${window.index.toString().padLeft(3, '0')}',
        recordingFormat:
            metadata?.recordingFormat ?? ref.read(recordingFormatProvider),
        gainLinear: session.settings.gainLinear ?? 1.0,
        highPassHz: session.settings.highPassHz ?? 0.0,
      );
      aruCaptureActive = !captureWasRunning;
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
