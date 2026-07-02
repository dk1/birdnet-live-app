import 'dart:math' as math;

import '../../live/live_session.dart';

double detectionDurationSeconds(
  DetectionRecord detection,
  SessionSettings settings,
) {
  final end = detection.endTimestamp;
  if (end != null && end.isAfter(detection.timestamp)) {
    return end.difference(detection.timestamp).inMicroseconds /
        Duration.microsecondsPerSecond;
  }
  return settings.windowDuration.toDouble();
}

DetectionAudioWindow detectionAudioWindow(
  LiveSession session,
  DetectionRecord detection, {
  double? clipContextSeconds,
}) {
  final context = math.max(0.0, clipContextSeconds ?? 0.0);
  final start =
      detection.timestamp.difference(session.startTime).inMicroseconds /
      Duration.microsecondsPerSecond;
  final duration = detectionDurationSeconds(detection, session.settings);
  final clipStart = math.max(0.0, start - context);
  final detectionStartInClip = start - clipStart;
  return DetectionAudioWindow(
    detectionStartSec: start,
    detectionDurationSec: duration,
    clipStartSec: clipStart,
    clipDurationSec: duration + context * 2,
    clipDetectionStartSec: detectionStartInClip,
    clipDetectionEndSec: detectionStartInClip + duration,
  );
}

class DetectionAudioWindow {
  const DetectionAudioWindow({
    required this.detectionStartSec,
    required this.detectionDurationSec,
    required this.clipStartSec,
    required this.clipDurationSec,
    required this.clipDetectionStartSec,
    required this.clipDetectionEndSec,
  });

  final double detectionStartSec;
  final double detectionDurationSec;
  final double clipStartSec;
  final double clipDurationSec;
  final double clipDetectionStartSec;
  final double clipDetectionEndSec;

  double get detectionEndSec => detectionStartSec + detectionDurationSec;
}
