// =============================================================================
// ARU Detection Sampler - Clip retention across scheduled cycles
// =============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../live/live_session.dart';
import '../survey/detection_sampler.dart';

/// Chooses which ARU detection clips remain on disk.
///
/// Detection records are always retained. This sampler only clears
/// [DetectionRecord.audioClipPath] and deletes the clip file when retention
/// limits require a clip to be dropped.
class AruDetectionSampler {
  AruDetectionSampler({
    required this.mode,
    this.topN = 10,
    this.minKeepPerSpecies = 3,
    String Function(DetectionRecord record)? scopeKeyFor,
    int Function(DetectionRecord record)? timeBucketFor,
    int Function(DetectionRecord record)? cycleIndexFor,
  }) : _scopeKeyFor = scopeKeyFor,
       _timeBucketFor = timeBucketFor ?? cycleIndexFor ?? _defaultTimeBucketFor;

  final SamplingMode mode;
  final int topN;
  final int minKeepPerSpecies;
  final String Function(DetectionRecord record)? _scopeKeyFor;
  final int Function(DetectionRecord record) _timeBucketFor;

  final Map<String, List<_KeptAruClip>> _keptClips = {};

  int get keptClipCount =>
      _keptClips.values.fold(0, (sum, list) => sum + list.length);
  int get droppedClipCount => _droppedClipCount;
  int _droppedClipCount = 0;

  Future<bool> onRecordClosed(DetectionRecord record) async {
    if (mode == SamplingMode.all) return record.audioClipPath != null;
    if (record.audioClipPath == null) return false;

    final groupKey = _groupKey(record);
    final timeBucket = _timeBucketFor(record);
    final kept = _keptClips.putIfAbsent(groupKey, () => []);
    final candidate = _KeptAruClip(record: record, timeBucket: timeBucket);

    if (mode == SamplingMode.smart && kept.length >= minKeepPerSpecies) {
      final sameBucket = _findSameBucket(candidate, kept);
      if (sameBucket != null) {
        if (record.confidence > sameBucket.record.confidence) {
          kept.remove(sameBucket);
          await _evictClip(sameBucket.record);
          _insertSorted(kept, candidate);
          return true;
        }
        await _evictClip(record);
        return false;
      }
    }

    if (kept.length < topN) {
      _insertSorted(kept, candidate);
      return true;
    }

    final eviction =
        mode == SamplingMode.smart
            ? _weakestFromMostRepresentedBucket(kept) ?? kept.first
            : kept.first;

    if (record.confidence > eviction.record.confidence) {
      kept.remove(eviction);
      await _evictClip(eviction.record);
      _insertSorted(kept, candidate);
      return true;
    }

    await _evictClip(record);
    return false;
  }

  void replaceRecord(DetectionRecord previous, DetectionRecord replacement) {
    final groupKey = _groupKey(previous);
    final kept = _keptClips[groupKey];
    if (kept == null) return;

    final existingIndex = kept.indexWhere(
      (clip) => identical(clip.record, previous),
    );
    if (existingIndex == -1) return;

    kept.removeAt(existingIndex);
    final replacementGroupKey = _groupKey(replacement);
    final replacementClip = _KeptAruClip(
      record: replacement,
      timeBucket: _timeBucketFor(replacement),
    );
    final target = _keptClips.putIfAbsent(replacementGroupKey, () => []);
    _insertSorted(target, replacementClip);
    if (kept.isEmpty) _keptClips.remove(groupKey);
  }

  String _groupKey(DetectionRecord record) {
    final scope = _scopeKeyFor?.call(record) ?? 'deployment';
    return '$scope\u0000${record.scientificName}';
  }

  _KeptAruClip? _findSameBucket(
    _KeptAruClip candidate,
    List<_KeptAruClip> kept,
  ) {
    for (final existing in kept) {
      if (existing.timeBucket == candidate.timeBucket) return existing;
    }
    return null;
  }

  _KeptAruClip? _weakestFromMostRepresentedBucket(List<_KeptAruClip> kept) {
    final counts = <int, int>{};
    for (final clip in kept) {
      counts[clip.timeBucket] = (counts[clip.timeBucket] ?? 0) + 1;
    }

    var maxCount = 0;
    for (final count in counts.values) {
      if (count > maxCount) maxCount = count;
    }
    if (maxCount <= 1) return null;

    _KeptAruClip? weakest;
    for (final clip in kept) {
      if (counts[clip.timeBucket] != maxCount) continue;
      if (weakest == null ||
          clip.record.confidence < weakest.record.confidence) {
        weakest = clip;
      }
    }
    return weakest;
  }

  Future<void> _evictClip(DetectionRecord record) async {
    final path = record.audioClipPath;
    record.audioClipPath = null;
    _droppedClipCount++;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[AruDetectionSampler] failed to delete clip: $e');
    }
  }

  static void _insertSorted(List<_KeptAruClip> list, _KeptAruClip item) {
    var i = 0;
    while (i < list.length &&
        list[i].record.confidence <= item.record.confidence) {
      i++;
    }
    list.insert(i, item);
  }

  static int _defaultTimeBucketFor(DetectionRecord record) {
    return record.timestamp.millisecondsSinceEpoch ~/ 60000;
  }
}

class _KeptAruClip {
  const _KeptAruClip({required this.record, required this.timeBucket});

  final DetectionRecord record;
  final int timeBucket;
}
