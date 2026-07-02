#ifndef RUNNER_NATIVE_AUDIO_DECODER_H_
#define RUNNER_NATIVE_AUDIO_DECODER_H_

#include <atomic>
#include <cstdint>
#include <string>
#include <vector>

// Decodes compressed audio files (AAC/M4A, MP3, WMA, and anything else
// Windows Media Foundation has a decoder for) to mono 16-bit PCM.
//
// This mirrors the Android (MediaExtractor + MediaCodec, see
// android/app/src/main/kotlin/.../NativeAudioDecoder.kt) and iOS
// (AVAssetReader, see ios/Runner/NativeAudioDecoder.swift) native decoders
// behind the app's `com.birdnet/audio_decoder` platform channel. Pure-Dart
// WAV/FLAC files never reach this path — see AudioDecoder.canDecodeDart in
// lib/features/recording/audio_decoder.dart.
class NativeAudioDecoder {
 public:
  struct Info {
    bool ok = false;
    std::string error;
    int sample_rate = 0;
    int64_t total_samples = 0;
  };

  struct RangeResult {
    bool ok = false;
    std::string error;
    int sample_rate = 0;
    int64_t total_samples = 0;
    bool reached_end = false;
    std::vector<uint8_t> pcm16le;  // mono, little-endian.
  };

  // Probes duration/sample rate without decoding full PCM.
  static Info Inspect(const std::string& utf8_path);

  // Decodes the whole file to mono PCM16 and writes it to |utf8_temp_path|.
  static Info DecodeToFile(const std::string& utf8_path,
                            const std::string& utf8_temp_path,
                            std::atomic<bool>* cancelled);

  // Decodes [start_sample, start_sample + count) to mono PCM16 in memory.
  static RangeResult DecodeRange(const std::string& utf8_path,
                                  int64_t start_sample,
                                  int64_t count,
                                  std::atomic<bool>* cancelled);
};

#endif  // RUNNER_NATIVE_AUDIO_DECODER_H_
