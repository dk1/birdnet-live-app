// =============================================================================
// detection_sharing_service.dart
// =============================================================================
// Builds a share payload for a single [DetectionRecord] and hands it to
// `share_plus`. The payload is intentionally terse and field-tool friendly:
//
//   BirdNET Live — Eurasian Wren (Troglodytes troglodytes)
//   87% · 2026-05-06T13:45:22Z
//   geo:50.7374,7.0982
//
// Lat/lon are emitted as a `geo:` URI so any maps app on the receiving device
// can open them directly. Coordinates are clamped to 4 decimal places (~11 m
// precision) to avoid leaking sub-meter device fingerprints when the
// recipient might re-share publicly. Timestamp is UTC (ISO 8601) — recipients
// in other timezones never have to guess what "13:45" means.
//
// When the detection has a kept audio clip, the file is attached via
// `Share.shareXFiles`; otherwise we fall back to text-only sharing via
// `Share.share`. Both paths use the same human-readable subject so threaded
// chat apps group them sensibly.
//
// This is a thin wrapper, not a stateful service — exposed as a top-level
// function so callers don't need a provider just to share one detection.
// =============================================================================

import 'dart:io';

import 'package:share_plus/share_plus.dart';

import '../../live/live_session.dart';

/// Share a single [detection] using the platform share sheet.
///
/// Attaches the detection's audio clip when one exists on disk; falls back
/// to a text-only share otherwise. Returns the [ShareResult] from
/// `share_plus` so callers can react to dismissal vs. successful share if
/// they want — most callers can ignore it.
Future<ShareResult> shareDetection(DetectionRecord detection) async {
  final body = _buildBody(detection);
  final subject = _buildSubject(detection);

  final clipPath = detection.audioClipPath;
  if (clipPath != null && File(clipPath).existsSync()) {
    return Share.shareXFiles([XFile(clipPath)], text: body, subject: subject);
  }
  return Share.share(body, subject: subject);
}

String _buildSubject(DetectionRecord d) {
  // Prefer the common name in the subject so the receiving app's preview
  // stays human-friendly; fall back to the scientific name if the common
  // name is empty (e.g. unknown species).
  final name = d.commonName.trim().isNotEmpty ? d.commonName : d.scientificName;
  return 'BirdNET Live: $name';
}

String _buildBody(DetectionRecord d) {
  final pct = (d.confidence * 100).round();
  final ts = d.timestamp.toUtc().toIso8601String();
  final lines = <String>[
    'BirdNET Live \u2014 ${d.commonName} (${d.scientificName})',
    '$pct% \u00b7 $ts',
  ];
  if (d.latitude != null && d.longitude != null) {
    lines.add(
      'geo:${d.latitude!.toStringAsFixed(4)},${d.longitude!.toStringAsFixed(4)}',
    );
  }
  if (d.isConfirmed) {
    lines.add('Confirmed');
  }
  return lines.join('\n');
}
