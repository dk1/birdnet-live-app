// =============================================================================
// ARU Detection Sampler - Clip retention across scheduled cycles
// =============================================================================

import '../live/live_session.dart';
import '../survey/detection_sampler.dart';

/// Chooses which ARU detection clips remain on disk.
///
/// Detection records are always retained. This sampler only clears
/// [DetectionRecord.audioClipPath] and deletes the clip file when retention
/// limits require a clip to be dropped.
///
/// Selection mirrors the Survey [DetectionSampler] exactly — Top N
/// highest-confidence clips per species, with a Smart mode that adds same-spot
/// rivalry and a [minKeepPerSpecies] floor — with one deliberate difference:
/// ARU deployments are stationary, so the Survey "same spot" test reduces to a
/// **time-only** proximity check (no haversine distance). Two detections of the
/// same species within [timeThresholdSeconds] are treated as the same
/// continuous vocalization, so only the strongest clip survives. This spreads
/// retained clips across a long deployment instead of clustering them on one
/// chatty bird in one short span.
///
/// Clip-file teardown is shared with the Survey sampler via
/// [deleteDetectionClipFile]. ARU additionally keys retention by an optional
/// [scopeKeyFor] (e.g. one budget per cycle when each cycle becomes its own
/// session) and supports mid-session [replaceRecord], since ARU detections are
/// re-synced from the live inference loop as immutable records.
class AruDetectionSampler {
  AruDetectionSampler({
    required this.mode,
    this.topN = 10,
    this.timeThresholdSeconds = 120,
    this.minKeepPerSpecies = 3,
    String Function(DetectionRecord record)? scopeKeyFor,
  }) : _scopeKeyFor = scopeKeyFor;

  /// Active sampling mode.
  final SamplingMode mode;

  /// Maximum number of clips to retain per species (Top N and Smart modes).
  final int topN;

  /// Same-spot time threshold in seconds (Smart mode only). Two detections of
  /// the same species within this window are considered the same continuous
  /// vocalization. Mirrors the Survey sampler's time threshold; distance is not
  /// used because ARU deployments are stationary.
  final int timeThresholdSeconds;

  /// Smart mode only: minimum number of clips to retain per species before
  /// same-spot rivalry kicks in. Until a species has this many kept clips, new
  /// detections fall through to the standard Top N admission path even if a
  /// same-spot neighbor exists.
  final int minKeepPerSpecies;

  final String Function(DetectionRecord record)? _scopeKeyFor;

  /// Per-group (scope + species) lists of records whose clips are currently
  /// kept on disk, sorted ascending by confidence (weakest at index 0).
  final Map<String, List<DetectionRecord>> _keptClips = {};

  int get keptClipCount =>
      _keptClips.values.fold(0, (sum, list) => sum + list.length);
  int get droppedClipCount => _droppedClipCount;
  int _droppedClipCount = 0;

  Future<bool> onRecordClosed(DetectionRecord record) async {
    // All mode: keep every clip, no work to do.
    if (mode == SamplingMode.all) return record.audioClipPath != null;

    // No clip on this record → nothing to manage.
    if (record.audioClipPath == null) return false;

    final groupKey = _groupKey(record);
    final kept = _keptClips.putIfAbsent(groupKey, () => []);

    // Smart mode: check for a same-spot rival first. If one exists, the contest
    // is between just those two regardless of free slots — but only after the
    // per-species minimum has been met, so the first few clips always survive.
    if (mode == SamplingMode.smart && kept.length >= minKeepPerSpecies) {
      final neighbor = _findSameSpot(record, kept);
      if (neighbor != null) {
        if (record.confidence > neighbor.confidence) {
          kept.remove(neighbor);
          await _evictClip(neighbor);
          _insertSorted(kept, record);
          return true;
        }
        await _evictClip(record);
        return false;
      }
      // No same-spot rival → fall through to standard Top N logic.
    }

    // Top N admission (shared by Top N and Smart-with-no-rival).
    if (kept.length < topN) {
      _insertSorted(kept, record);
      return true;
    }

    // Budget full — compare against the weakest kept clip.
    final weakest = kept.first;
    if (record.confidence > weakest.confidence) {
      kept.removeAt(0);
      await _evictClip(weakest);
      _insertSorted(kept, record);
      return true;
    }

    // New record is no better than the weakest kept clip — drop it.
    await _evictClip(record);
    return false;
  }

  /// Re-point a previously-kept clip at its replacement record.
  ///
  /// ARU detections are re-synced from the live inference loop as fresh
  /// immutable [DetectionRecord]s (e.g. when a detection's confidence updates),
  /// so the kept list must follow the new instance to keep later evictions
  /// clearing the record that actually lives in the session.
  void replaceRecord(DetectionRecord previous, DetectionRecord replacement) {
    final previousKey = _groupKey(previous);
    final kept = _keptClips[previousKey];
    if (kept == null) return;

    final index = kept.indexWhere((record) => identical(record, previous));
    if (index == -1) return;

    kept.removeAt(index);
    if (kept.isEmpty) _keptClips.remove(previousKey);

    final target = _keptClips.putIfAbsent(_groupKey(replacement), () => []);
    _insertSorted(target, replacement);
  }

  String _groupKey(DetectionRecord record) {
    final scope = _scopeKeyFor?.call(record) ?? 'deployment';
    return '$scope\u0000${record.scientificName}';
  }

  DetectionRecord? _findSameSpot(
    DetectionRecord candidate,
    List<DetectionRecord> kept,
  ) {
    for (final existing in kept) {
      if (_isSameSpot(candidate, existing)) return existing;
    }
    return null;
  }

  /// Whether two same-species detections fall in the same time window.
  ///
  /// ARU is stationary, so location never differentiates clips; only time does.
  bool _isSameSpot(DetectionRecord a, DetectionRecord b) {
    final timeDiff = a.timestamp.difference(b.timestamp).inSeconds.abs();
    return timeDiff <= timeThresholdSeconds;
  }

  Future<void> _evictClip(DetectionRecord record) async {
    final path = record.audioClipPath;
    record.audioClipPath = null;
    _droppedClipCount++;
    await deleteDetectionClipFile(path, logTag: 'AruDetectionSampler');
  }

  /// Insert into a list sorted ascending by confidence.
  static void _insertSorted(List<DetectionRecord> list, DetectionRecord item) {
    var i = 0;
    while (i < list.length && list[i].confidence <= item.confidence) {
      i++;
    }
    list.insert(i, item);
  }
}
