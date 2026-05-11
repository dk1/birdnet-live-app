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

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
    // Stage a copy under a human-readable name that matches the
    // `BirdNET_Live_<timestamp>_<species>.<ext>` scheme used by ZIP
    // exports. The on-disk clip is named `clip_<ms>.<ext>`, which is
    // unhelpful in a chat thread or files app; we copy into the
    // platform temp dir so share_plus exposes the friendlier name to
    // receivers without mutating the session storage.
    final staged = await _stageClipForShare(File(clipPath), detection);
    return Share.shareXFiles(
      [XFile(staged.path)],
      text: body,
      subject: subject,
    );
  }
  return Share.share(body, subject: subject);
}

/// Copies [clip] into the temp dir under the export-style filename so the
/// share sheet exposes a friendly name. Reuses an existing staged file when
/// the names already match to avoid extra IO on repeat shares.
Future<File> _stageClipForShare(File clip, DetectionRecord d) async {
  final ext = p.extension(clip.path);
  final name = _exportClipName(d, ext);
  final tmp = await getTemporaryDirectory();
  final shareDir = Directory(p.join(tmp.path, 'shared_clips'));
  if (!shareDir.existsSync()) shareDir.createSync(recursive: true);
  final target = File(p.join(shareDir.path, name));
  // Always overwrite: the source clip may have been re-encoded since
  // the previous share and the cost is a single small file copy.
  await clip.copy(target.path);
  return target;
}

/// Builds the share filename for a single detection clip.
///
/// Mirrors the ZIP export scheme (`BirdNET_Live_<dt>_clip_NNN_<species>.<ext>`)
/// but drops the per-session sequence number since a single share has no
/// containing collection. The detection's own timestamp anchors the name.
String _exportClipName(DetectionRecord d, String ext) {
  final dt = DateFormat(
    'yyyy-MM-dd_HH-mm-ss',
  ).format(d.timestamp.toLocal());
  final species = _sanitizeFilename(
    d.commonName.trim().isNotEmpty ? d.commonName : d.scientificName,
  );
  return 'BirdNET_Live_${dt}_$species$ext';
}

/// Replaces filesystem-illegal characters with underscores and collapses
/// runs of whitespace/underscores. Kept in sync with the equivalent helper
/// in `session_export.dart` so shared clips and exported clips match.
String _sanitizeFilename(String input) {
  return input
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
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
