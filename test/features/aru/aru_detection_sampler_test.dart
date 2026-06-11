import 'package:birdnet_live/features/aru/aru_detection_sampler.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/survey/detection_sampler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 6, 1, 4);

  DetectionRecord record({
    required double confidence,
    required int cycle,
    String species = 'Turdus merula',
    String clip = 'clip.flac',
  }) {
    return DetectionRecord(
      scientificName: species,
      commonName: 'Eurasian Blackbird',
      confidence: confidence,
      timestamp: start.add(Duration(hours: cycle)),
      audioClipPath: '/tmp/$cycle-$confidence-$clip',
    );
  }

  int cycleIndexFor(DetectionRecord r) => r.timestamp.difference(start).inHours;

  group('AruDetectionSampler', () {
    test('all mode keeps every clip', () async {
      final sampler = AruDetectionSampler(
        mode: SamplingMode.all,
        cycleIndexFor: cycleIndexFor,
      );
      final det = record(confidence: 0.5, cycle: 0);

      final kept = await sampler.onRecordClosed(det);

      expect(kept, isTrue);
      expect(det.audioClipPath, isNotNull);
      expect(sampler.droppedClipCount, 0);
    });

    test('topN keeps highest-confidence clips per species', () async {
      final sampler = AruDetectionSampler(
        mode: SamplingMode.topN,
        topN: 2,
        cycleIndexFor: cycleIndexFor,
      );
      final low = record(confidence: 0.3, cycle: 0);
      final mid = record(confidence: 0.6, cycle: 1);
      final high = record(confidence: 0.9, cycle: 2);

      expect(await sampler.onRecordClosed(low), isTrue);
      expect(await sampler.onRecordClosed(mid), isTrue);
      expect(await sampler.onRecordClosed(high), isTrue);

      expect(low.audioClipPath, isNull);
      expect(mid.audioClipPath, isNotNull);
      expect(high.audioClipPath, isNotNull);
      expect(sampler.keptClipCount, 2);
      expect(sampler.droppedClipCount, 1);
    });

    test('smart mode keeps stronger clip from the same cycle', () async {
      final sampler = AruDetectionSampler(
        mode: SamplingMode.smart,
        topN: 3,
        minKeepPerSpecies: 0,
        cycleIndexFor: cycleIndexFor,
      );
      final weaker = record(confidence: 0.4, cycle: 0);
      final stronger = record(confidence: 0.8, cycle: 0);

      expect(await sampler.onRecordClosed(weaker), isTrue);
      expect(await sampler.onRecordClosed(stronger), isTrue);

      expect(weaker.audioClipPath, isNull);
      expect(stronger.audioClipPath, isNotNull);
      expect(sampler.keptClipCount, 1);
    });

    test('smart mode prefers replacing overrepresented cycles', () async {
      final sampler = AruDetectionSampler(
        mode: SamplingMode.smart,
        topN: 3,
        minKeepPerSpecies: 10,
        cycleIndexFor: cycleIndexFor,
      );
      final cycle0Low = record(confidence: 0.4, cycle: 0, clip: 'a.flac');
      final cycle0Mid = record(confidence: 0.5, cycle: 0, clip: 'b.flac');
      final cycle1Mid = record(confidence: 0.6, cycle: 1, clip: 'c.flac');
      final cycle2High = record(confidence: 0.7, cycle: 2, clip: 'd.flac');

      expect(await sampler.onRecordClosed(cycle0Low), isTrue);
      expect(await sampler.onRecordClosed(cycle0Mid), isTrue);
      expect(await sampler.onRecordClosed(cycle1Mid), isTrue);
      expect(await sampler.onRecordClosed(cycle2High), isTrue);

      expect(cycle0Low.audioClipPath, isNull);
      expect(cycle0Mid.audioClipPath, isNotNull);
      expect(cycle1Mid.audioClipPath, isNotNull);
      expect(cycle2High.audioClipPath, isNotNull);
      expect(sampler.keptClipCount, 3);
    });

    test('smart mode does not mix species budgets', () async {
      final sampler = AruDetectionSampler(
        mode: SamplingMode.smart,
        topN: 1,
        cycleIndexFor: cycleIndexFor,
      );
      final blackbird = record(confidence: 0.4, cycle: 0);
      final robin = record(
        confidence: 0.3,
        cycle: 0,
        species: 'Erithacus rubecula',
      );

      expect(await sampler.onRecordClosed(blackbird), isTrue);
      expect(await sampler.onRecordClosed(robin), isTrue);

      expect(blackbird.audioClipPath, isNotNull);
      expect(robin.audioClipPath, isNotNull);
      expect(sampler.keptClipCount, 2);
    });

    test('smart mode does not mix sampling scopes', () async {
      final sampler = AruDetectionSampler(
        mode: SamplingMode.smart,
        topN: 1,
        minKeepPerSpecies: 0,
        scopeKeyFor: (record) => 'cycle-${cycleIndexFor(record)}',
        timeBucketFor: (_) => 0,
      );
      final cycle0 = record(confidence: 0.4, cycle: 0);
      final cycle1 = record(confidence: 0.3, cycle: 1);

      expect(await sampler.onRecordClosed(cycle0), isTrue);
      expect(await sampler.onRecordClosed(cycle1), isTrue);

      expect(cycle0.audioClipPath, isNotNull);
      expect(cycle1.audioClipPath, isNotNull);
      expect(sampler.keptClipCount, 2);
    });

    test('smart mode distributes clips across time buckets', () async {
      final sampler = AruDetectionSampler(
        mode: SamplingMode.smart,
        topN: 2,
        minKeepPerSpecies: 10,
        timeBucketFor: cycleIndexFor,
      );
      final minute0Low = record(confidence: 0.4, cycle: 0, clip: 'a.flac');
      final minute0Mid = record(confidence: 0.5, cycle: 0, clip: 'b.flac');
      final minute1High = record(confidence: 0.6, cycle: 1, clip: 'c.flac');

      expect(await sampler.onRecordClosed(minute0Low), isTrue);
      expect(await sampler.onRecordClosed(minute0Mid), isTrue);
      expect(await sampler.onRecordClosed(minute1High), isTrue);

      expect(minute0Low.audioClipPath, isNull);
      expect(minute0Mid.audioClipPath, isNotNull);
      expect(minute1High.audioClipPath, isNotNull);
      expect(sampler.keptClipCount, 2);
    });
  });
}
