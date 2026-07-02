import 'dart:io';
import 'dart:typed_data';

import '../../recording/audio_decoder.dart';
import '../../recording/flac_encoder.dart';
import '../../recording/wav_writer.dart';

class AudioExportNormalizer {
  AudioExportNormalizer._();

  static const double quietThreshold = 0.5;
  static const double targetPeak = 0.95;

  static Future<void> normalizeFileInPlace(File file, String extension) async {
    try {
      final ext = extension.toLowerCase();
      if (ext != '.wav' && ext != '.flac') return;
      if (!await file.exists()) return;

      final decoded = await AudioDecoder.decodeFile(file.path);
      final peak = computePeak(decoded.samples);
      if (peak == 0.0 || peak >= quietThreshold) return;

      final normalized = normalizedFloat32(decoded.samples, peak);
      if (ext == '.flac') {
        await FlacEncoder.writeFile(
          filePath: file.path,
          samples: normalized,
          sampleRate: decoded.sampleRate,
        );
      } else {
        await WavWriter.writeFile(
          filePath: file.path,
          samples: normalized,
          sampleRate: decoded.sampleRate,
        );
      }
    } catch (_) {
      // Export must still succeed if normalization fails.
    }
  }

  static double computePeak(Int16List samples) {
    var peak = 0;
    for (var i = 0; i < samples.length; i++) {
      final v = samples[i];
      final abs = v < 0 ? -v : v;
      if (abs > peak) peak = abs;
    }
    return peak / 32768.0;
  }

  static Float32List normalizedFloat32(Int16List samples, double peak) {
    final gain = targetPeak / peak;
    final out = Float32List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      var v = samples[i] / 32768.0 * gain;
      if (v > 1.0) v = 1.0;
      if (v < -1.0) v = -1.0;
      out[i] = v;
    }
    return out;
  }
}
